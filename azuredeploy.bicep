param location string = resourceGroup().location

@description('Name of azure web app')
param siteName string

@description('Stack settings')
param linuxFxVersion string = 'php|7.4'

@description('Database administrator login name')
@minLength(1)
param administratorLogin string = 'redcap_app'

@description('Database administrator password')
@minLength(8)
@secure()
param administratorLoginPassword string

@description('REDCap zip file URI.')
param redcapAppZip string = ''

@description('REDCap Community site username for downloading the REDCap zip file.')
param redcapCommunityUsername string

@description('REDCap Community site password for downloading the REDCap zip file.')
@secure()
param redcapCommunityPassword string

@description('REDCap zip file version to be downloaded from the REDCap Community site.')
param redcapAppZipVersion string = 'latest'

@description('Email address configured as the sending address in REDCap')
param fromEmailAddress string

@description('Fully-qualified domain name of your SMTP relay endpoint')
param smtpFQDN string

@description('Login name for your SMTP relay')
param smtpUser string

@description('Login password for your SMTP relay')
@secure()
param smtpPassword string

@description('Port for your SMTP relay')
param smtpPort string = '587'

@description('Describes plan\'s pricing tier and capacity - this can be changed after deployment. Check details at https://azure.microsoft.com/en-us/pricing/details/app-service/')
@allowed([
  'F1'
  'D1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1v2'
  'P2v2'
  'P3v2'
  'P1v3'
  'P2v3'
  'P3v3'
])
param skuName string = 'S1'

@description('Describes plan\'s instance count (how many distinct web servers will be deployed in the farm) - this can be changed after deployment')
@minValue(1)
param skuCapacity int = 1

@description('Initial MySQL database storage size in GB ')
param databaseStorageSizeGB int = 32

@description('Initial MySQL databse storage IOPS')
param databaseStorageIops int = 396

@allowed([
  'Enabled'
  'Disabled'
])
param databaseStorageAutoGrow string = 'Enabled'

@allowed([
  'Enabled'
  'Disabled'
])
param databseStorageAutoIoScaling string = 'Enabled'

@description('MySQL version')
@allowed([
  '5.6'
  '5.7'
])
param mysqlVersion string = '5.7'

@description('The default selected is \'Locally Redundant Storage\' (3 copies in one region). See https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy for more information.')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Premium_LRS'
])
param storageType string = 'Standard_LRS'

@description('Name of the container used to store backing files in the new storage account. This container is created automatically during deployment.')
param storageContainerName string = 'redcap'

@description('The path to the deployment source files on GitHub')
param repoURL string = 'https://github.com/microsoft/azure-redcap-paas.git'

@description('The main branch of the application repo')
param branch string = 'main'

var siteNameCleaned = replace(siteName, ' ', '')
var databaseName = '${siteNameCleaned}_db'
var uniqueServerName = '${siteNameCleaned}${uniqueString(resourceGroup().id)}'
var hostingPlanNameCleaned = '${siteNameCleaned}_serviceplan'
var uniqueWebSiteName = '${siteNameCleaned}${uniqueString(resourceGroup().id)}'
var uniqueStorageName = 'storage${uniqueString(resourceGroup().id)}'
var storageAccountId = '${resourceGroup().id}/providers/Microsoft.Storage/storageAccounts/${uniqueStorageName}'
var uniqueFileShareStorageAccountName = 'fsrc${uniqueString(resourceGroup().id)}'
var fileShareStorageAccountId = '${resourceGroup().id}/providers/Microsoft.Storage/storageAccounts/${uniqueFileShareStorageAccountName}'
var keyVaultName = 'kv${uniqueString(resourceGroup().id)}'
var addressSpace = [
  '10.230.0.0/24'
]

var privateLinkSubnet = {
  name: 'PrivateLinkSubnet'
  subnetPrefix: '10.230.0.0/27'
}

var computeSubnet = {
  name: 'ComputeSubnet'
  subnetPrefix: '10.230.0.32/27'
}

var integrationSubnet = {
  name: 'IntegrationSubnet'
  subnetPrefix: '10.230.0.64/26'
}

var mySqlSubnet = {
  name: 'MySQLFlexSubnet'
  subnetPrefix: '10.230.0.128/29'
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'redcap'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressSpace
    }
  }
}

resource redcapPrivateLinkSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  name: privateLinkSubnet.name
  parent: virtualNetwork
  properties: {
    addressPrefix: privateLinkSubnet.subnetPrefix
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
      }
      {
        service: 'Microsoft.Storage'
      }
    ]
  }
}

resource redcapComputeSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  name: computeSubnet.name
  parent: virtualNetwork
  properties: {
    addressPrefix: computeSubnet.subnetPrefix
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
      }
      {
        service: 'Microsoft.Storage'
      }
    ]
  }
  dependsOn: [
    redcapPrivateLinkSubnet
  ]
}

resource redcapIntegrationSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  name: integrationSubnet.name
  parent: virtualNetwork
  properties: {
    addressPrefix: integrationSubnet.subnetPrefix
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
      }
      {
        service: 'Microsoft.Storage'
      }
    ]
  }
  dependsOn: [
    redcapComputeSubnet
  ]
}

resource redcapSqlSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  name: mySqlSubnet.name
  parent: virtualNetwork
  properties: {
    addressPrefix: mySqlSubnet.subnetPrefix
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
      }
      {
        service: 'Microsoft.Storage'
      }
    ]
    delegations: [
      {
        name: 'Microsoft.DBforMySQL/flexibleServers'
        properties: {
          serviceName: 'Microsoft.DBforMySQL/flexibleServers'
        }
      }
    ]
  }
  dependsOn: [
    redcapIntegrationSubnet
  ]
}

resource storageName 'Microsoft.Storage/storageAccounts@2016-01-01' = {
  name: uniqueStorageName
  location: location
  sku: {
    name: storageType
  }
  tags: {
    displayName: 'BackingStorage'
  }
  kind: 'Storage'
  dependsOn: []
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  name: 'default'
  parent: storageName
}

resource storageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: storageContainerName
  parent: blobServices
}

resource fileShareStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: uniqueFileShareStorageAccountName
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  tags: {
    displayName: 'FileStorage'
  }
  kind: 'FileStorage'
  properties: {
    accessTier: 'Hot'
    networkAcls: {
      bypass: 'Logging,Metrics,AzureServices'
      defaultAction: 'Deny'
      // TODO data.http.ifconfig.body
      // ipRules: [
      //   {
      //     action: 'Allow'
      //     value: 'string'
      //   }
      // ]
      virtualNetworkRules: [
        {
          action: 'Allow'
          id: redcapPrivateLinkSubnet.id
        }
        {
          action: 'Allow'
          id: redcapComputeSubnet.id
        }
        {
          action: 'Allow'
          id: redcapIntegrationSubnet.id
        }
        {
          action: 'Allow'
          id: redcapSqlSubnet.id
        }
        // TODO Devops subnet id
        // {
        //   action: 'Allow'
        //   id: ''
        // }
      ]
    }
  }
  dependsOn: []
}

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = {
  name: 'default'
  parent: fileShareStorageAccount
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  name: storageContainerName
  parent: fileServices
  properties: {
    accessTier: 'Premium'
    shareQuota: 100
  }
}

resource hostingPlanName 'Microsoft.Web/serverfarms@2016-09-01' = {
  name: hostingPlanNameCleaned
  location: location
  tags: {
    displayName: 'HostingPlan'
  }
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  kind: 'linux'
  properties: {
    name: hostingPlanNameCleaned
    reserved: true
  }
}

resource webSiteName 'Microsoft.Web/sites@2016-08-01' = {
  name: uniqueWebSiteName
  location: location
  identity:{
    type: 'SystemAssigned'
  }
  tags: {
    displayName: 'WebApp'
  }
  properties: {
    name: uniqueWebSiteName
    serverFarmId: hostingPlanNameCleaned
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: true
      appCommandLine: '/home/startup.sh'
      appSettings: [
        {
          name: 'StorageContainerName'
          value: storageContainerName
        }
        {
          name: 'StorageAccount'
          value: uniqueStorageName
        }
        {
          name: 'StorageKey'
          value: concat(listKeys(storageAccountId, '2015-05-01-preview').key1)
        }
        {
          name: 'redcapAppZip'
          value: redcapAppZip
        }
        {
          name: 'redcapCommunityUsername'
          value: redcapCommunityUsername
        }
        {
          name: 'redcapCommunityPassword'
          value: redcapCommunityPassword
        }
        {
          name: 'redcapAppZipVersion'
          value: redcapAppZipVersion
        }
        {
          name: 'DBHostName'
          value: '${uniqueServerName}.mysql.database.azure.com'
        }
        {
          name: 'DBName'
          value: databaseName
        }
        {
          name: 'DBUserName'
          value: administratorLogin
        }
        {
          name: 'DBPassword'
          value: administratorLoginPassword
        }
        {
          name: 'DBSslCa'
          value: '/home/site/wwwroot/DigiCertGlobalRootCA.crt.pem'
        }
        {
          name: 'PHP_INI_SCAN_DIR'
          value: '/usr/local/etc/php/conf.d:/home/site'
        }
        {
          name: 'from_email_address'
          value: fromEmailAddress
        }
        {
          name: 'smtp_fqdn_name'
          value: smtpFQDN
        }
        {
          name: 'smtp_port'
          value: smtpPort
        }
        {
          name: 'smtp_user_name'
          value: smtpUser
        }
        {
          name: 'smtp_password'
          value: smtpPassword
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: '1'
        }
      ]
    }
  }
  dependsOn: [
    hostingPlanName
    storageName
  ]
}

resource webSiteName_web 'Microsoft.Web/sites/sourcecontrols@2015-08-01' = {
  parent: webSiteName
  name: 'web'
  location: location
  tags: {
    displayName: 'CodeDeploy'
  }
  properties: {
    repoUrl: repoURL
    branch: branch
    isManualIntegration: true
  }
  dependsOn: [
    serverName
  ]
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    tenantId: tenant().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    sku: {
      name: 'standard'
      family: 'A'
    }
    accessPolicies:[
      {
        objectId: webSiteName.identity.principalId
        permissions: {
          certificates: [
            'all'
          ]
          keys: [
            'backup'
            'create'
            'decrypt'
            'delete'
            'encrypt'
            'get'
            'import'
            'list'
            'purge'
            'recover'
            'restore'
            'sign'
            'unwrapKey'
            'update'
            'verify'
            'wrapKey'
          ]
          secrets: [
            'backup'
            'delete'
            'get'
            'list'
            'purge'
            'recover'
            'restore'
            'set'
          ]
          storage: [
            'backup'
            'delete'
            'deletesas'
            'get'
            'getsas'
            'list'
            'listsas'
            'purge'
            'recover'
            'regeneratekey'
            'restore'
            'set'
            'setsas'
            'update'
          ]
        }
        tenantId: tenant().tenantId
      }
    ]
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
      // TODO data.http.ifconfig.body
      // ipRules: [
      //   {
      //     value: 'string'
      //   }
      // ]
      virtualNetworkRules: [
        {
          id: redcapPrivateLinkSubnet.id
        }
        {
          id: redcapComputeSubnet.id
        }
        {
          id: redcapIntegrationSubnet.id
        }
        {
          id: redcapSqlSubnet.id
        }
        // TODO Devops subnet id
        // {
        //   action: 'Allow'
        //   id: ''
        // }
      ]
    }
  }
}


resource secretMySql 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'mysql-password'
  properties: {
    value: administratorLoginPassword
  }
  dependsOn:[]
}

resource secretStorage 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'storage-key'
  properties: {
    value: storageName.listKeys().keys[0].value
  }
  dependsOn:[]
}

resource secretConnectionString 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'connection-string'
  properties: {
    value: 'Database=${databaseName};Data Source=${uniqueServerName}.mysql.database.azure.com;User Id=${administratorLogin}@mysql-${uniqueServerName};Password=${administratorLoginPassword}'
  }
  dependsOn:[]
}

resource secretRCZip 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'redcap-zipfile'
  properties: {
    value: redcapAppZip
  }
  dependsOn:[]
}

resource secretRCUser 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'redcap-username'
  properties: {
    value: redcapCommunityUsername
  }
  dependsOn:[]
}

resource secretRCPass 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: 'redcap-password'
  properties: {
    value: redcapCommunityPassword
  }
  dependsOn:[]
}

resource serverName 'Microsoft.DBforMySQL/flexibleServers@2021-12-01-preview' = {
  location: location
  name: uniqueServerName
  tags: {
    displayName: 'MySQLAzure'
  }
  properties: {
    version: mysqlVersion
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    storage: {
      storageSizeGB: databaseStorageSizeGB
      iops: databaseStorageIops
      autoGrow: databaseStorageAutoGrow
      autoIoScaling: databseStorageAutoIoScaling
    }
    network: {
      delegatedSubnetResourceId: redcapSqlSubnet.id
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    replicationRole: 'None'
  }
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  dependsOn: []
}

resource serverName_AllowAzureIPs 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2021-12-01-preview' = {
  parent: serverName
  name: 'AllowAzureIPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
  dependsOn: [
    serverName_databaseName
  ]
}

resource serverName_databaseName 'Microsoft.DBforMySQL/flexibleServers/databases@2021-12-01-preview' = {
  parent: serverName
  name: databaseName
  properties: {
    charset: 'utf8'
    collation: 'utf8_general_ci'
  }
}

output MySQLHostName string = '${uniqueServerName}.mysql.database.azure.com'
output MySqlUserName string = '${administratorLogin}@${uniqueServerName}'
output webSiteFQDN string = '${uniqueWebSiteName}.azurewebsites.net'
output storageAccountName string = uniqueStorageName
output storageContainerName string = storageContainerName
