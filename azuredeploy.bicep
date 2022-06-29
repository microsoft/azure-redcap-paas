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

@description('Azure database for MySQL sku Size ')
param databaseSkuSizeMB int = 5120

@description('Select MySql server performance tier. Please review https://docs.microsoft.com/en-us/azure/mysql/concepts-pricing-tiers and ensure your choices are available in the selected region.')
@allowed([
  'Basic'
  'GeneralPurpose'
  'MemoryOptimized'
])
param databaseForMySqlTier string = 'GeneralPurpose'

@description('Select MySql compute generation. Please review https://docs.microsoft.com/en-us/azure/mysql/concepts-pricing-tiers and ensure your choices are available in the selected region.')
@allowed([
  'Gen4'
  'Gen5'
])
param databaseForMySqlFamily string = 'Gen5'

@description('Select MySql vCore count. Please review https://docs.microsoft.com/en-us/azure/mysql/concepts-pricing-tiers and ensure your choices are available in the selected region.')
@allowed([
  1
  2
  4
  8
  16
  32
])
param databaseForMySqlCores int = 2

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

var siteName_var = replace(siteName, ' ', '')
var databaseName = '${siteName_var}_db'
var serverName_var = '${siteName_var}${uniqueString(resourceGroup().id)}'
var hostingPlanName_var = '${siteName_var}_serviceplan'
var webSiteName_var = '${siteName_var}${uniqueString(resourceGroup().id)}'
var tierSymbol = {
  Basic: 'B'
  GeneralPurpose: 'GP'
  MemoryOptimized: 'MO'
}
var databaseForMySqlSku = '${tierSymbol[databaseForMySqlTier]}_${databaseForMySqlFamily}_${databaseForMySqlCores}'
var storageName_var = 'storage${uniqueString(resourceGroup().id)}'
var storageAccountId = '${resourceGroup().id}/providers/Microsoft.Storage/storageAccounts/${storageName_var}'

resource storageName 'Microsoft.Storage/storageAccounts@2016-01-01' = {
  name: storageName_var
  location: resourceGroup().location
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

resource hostingPlanName 'Microsoft.Web/serverfarms@2016-09-01' = {
  name: hostingPlanName_var
  location: resourceGroup().location
  tags: {
    displayName: 'HostingPlan'
  }
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  kind: 'linux'
  properties: {
    name: hostingPlanName_var
    reserved: true
  }
}

resource webSiteName 'Microsoft.Web/sites@2016-08-01' = {
  name: webSiteName_var
  location: resourceGroup().location
  tags: {
    displayName: 'WebApp'
  }
  properties: {
    name: webSiteName_var
    serverFarmId: hostingPlanName_var
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: true
      connectionStrings: [
        {
          name: 'defaultConnection'
          connectionString: 'Database=${databaseName};Data Source=${serverName_var}.mysql.database.azure.com;User Id=${administratorLogin}@${serverName_var};Password=${administratorLoginPassword}'
          type: 'MySql'
        }
      ]
      appCommandLine: '/home/startup.sh'
      appSettings: [
        {
          name: 'StorageContainerName'
          value: storageContainerName
        }
        {
          name: 'StorageAccount'
          value: storageName_var
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
          value: '${serverName_var}.mysql.database.azure.com'
        }
        {
          name: 'DBName'
          value: databaseName
        }
        {
          name: 'DBUserName'
          value: '${administratorLogin}@${serverName_var}'
        }
        {
          name: 'DBPassword'
          value: administratorLoginPassword
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
  location: resourceGroup().location
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

resource serverName 'Microsoft.DBforMySQL/servers@2017-12-01-preview' = {
  location: resourceGroup().location
  name: serverName_var
  tags: {
    displayName: 'MySQLAzure'
  }
  properties: {
    version: mysqlVersion
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    storageProfile: {
      storageMB: databaseSkuSizeMB
      backupRetentionDays: '7'
      geoRedundantBackup: 'Disabled'
    }
    sslEnforcement: 'Disabled'
  }
  sku: {
    name: databaseForMySqlSku
  }
}

resource serverName_AllowAzureIPs 'Microsoft.DBforMySQL/servers/firewallrules@2017-12-01-preview' = {
  parent: serverName
  location: resourceGroup().location
  name: 'AllowAzureIPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
  dependsOn: [
    serverName_databaseName
  ]
}

resource serverName_databaseName 'Microsoft.DBforMySQL/servers/databases@2017-12-01' = {
  parent: serverName
  name: '${databaseName}'
  tags: {
    displayName: 'DB'
  }
  properties: {
    charset: 'utf8'
    collation: 'utf8_general_ci'
  }
}

output MySQLHostName string = '${serverName_var}.mysql.database.azure.com'
output MySqlUserName string = '${administratorLogin}@${serverName_var}'
output webSiteFQDN string = '${webSiteName_var}.azurewebsites.net'
output storageAccountKey string = concat(listKeys(storageAccountId, '2015-05-01-preview').key1)
output storageAccountName string = storageName_var
output storageContainerName string = storageContainerName
