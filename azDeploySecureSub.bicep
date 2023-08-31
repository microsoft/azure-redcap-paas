targetScope = 'subscription'

@allowed([
  'eastus'
  'westus'
])
param location string = 'eastus'

@allowed([
  'test'
  'demo'
  'prod'
])
param environment string = 'demo'
param workloadName string = 'redcap'
param namingConvention string = '{workloadName}-{env}-{rtype}-{loc}-{seq}'
param sequence int = 1

var myObjectId = 'd9608212-09d1-440a-a543-585ee85fcdf2'
var vnetName = nameModule[0].outputs.shortName
var strgName = nameModule[1].outputs.shortName
var webAppName = nameModule[2].outputs.shortName
var kvName = nameModule[3].outputs.shortName
var sqlName = nameModule[4].outputs.shortName
var sqlAdmin = 'sqladmin'
var sqlPassword = 'P@ssw0rd' // this should be linked to keyvault secret.

var subnets = {
  PrivateLinkSubnet: {
    addressPrefix: '10.230.0.0/27'
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
    ]
  }
  ComputeSubnet: {
    addressPrefix: '10.230.0.32/27'
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Web'
        locations: [
          location
        ]
      }
    ]
  }
  IntegrationSubnet: {
    addressPrefix: '10.230.0.64/26'
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Web'
        locations: [
          location
        ]
      }
    ]
    delegation: 'Microsoft.Web/serverFarms'
  }
  MySQLFlexSubnet: {
    addressPrefix: '10.230.0.128/29'
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
    ]
    delegation: 'Microsoft.DBforMySQL/flexibleServers'
  }
}

var tags = {
  workload: workloadName
  environment: environment
}

var secrets = [
  {
    name: 'sqlAdminName'
    value: mysqlDbserver.outputs.sqlAdmin
  }
  {
    name: 'sqlPassword'
    value: sqlPassword
  }
  {
    name: 'dbHostName'
    value: mysqlDbserver.outputs.mySqlServerName
  }
  {
    name: 'dbName'
    value: mysqlDbserver.outputs.databaseName
  }
]

var workloads = [
  'vnet'
  'st'
  'webApp'
  'kv'
  'mysql'
]

@batchSize(1)
module nameModule 'modules/common/createValidAzResourceName.bicep' = [for workload in workloads: {
  name: 'nameGeneration-${workload}'
  params: {
    location: location
    environment: environment
    namingConvention: namingConvention
    resourceType: workload
    sequence: sequence
    workloadName: workloadName
    addRandomChars: 4
  }
}]

module roles './modules/common/roles.bicep' = {
  name: 'Roles'
}

module kvSecrets './modules/common/appSvcKeyVaultRefs.bicep' = {
  name: 'secrets'
  params: {
    keyVaultName: kvName
    secretNames: secrets
  }
}

module virtualNetwork './modules/networking/main.bicep' = {
  name: 'vnetDeploy'
  params: {
    resourceGroupName: toUpper('RG-${vnetName}')
    virtualNetworkName: vnetName
    vnetAddressPrefix: '10.230.0.0/24'
    location: location
    subnets: subnets
    customDnsIPs: []
    tags: tags
    customTags: {
      workloadType: 'networking'
    }
  }
}

module storageAccounts './modules/storage/main.bicep' = {
  name: 'strgDeploy'
  dependsOn: [ virtualNetwork ]
  params: {
    resourceGroupName: toUpper('RG-${strgName}')
    location: location
    storageAccountName: strgName
    peSubnetId: virtualNetwork.outputs.subnets.PrivateLinkSubnet.id
    storageContainerName: 'redcap'
    kind: 'StorageV2'
    storageAccountSku: 'Standard_LRS'
    virtualNetworkId: virtualNetwork.outputs.virtualNetworkId
    privateDnsZoneName: 'privatelink.blob.core.windows.net'
    tags: tags
    customTags: {
      workloadType: 'storageAccount'
    }
  }
}

module keyvault './modules/kv/main.bicep' = {
  name: 'kvDeploy'
  params: {
    resourceGroupName: toUpper('RG-${kvName}')
    keyVaultName: kvName
    location: location
    tags: tags
    customTags: {
      workloadType: 'keyVault'
    }
    peSubnetId: virtualNetwork.outputs.subnets.PrivateLinkSubnet.id
    virtualNetworkId: virtualNetwork.outputs.virtualNetworkId
    roleAssignments: [
      {
        RoleDefinitionId: roles.outputs.roles['Key Vault Administrator']
        objectId: myObjectId
      }
      {
        RoleDefinitionId: roles.outputs.roles['Key Vault Secrets User']
        objectId: webApp.outputs.webAppIdentity
      }
    ]
    privateDnsZoneName: 'privatelink.vaultcore.azure.net'
    secrets: secrets
  }
}

module mysqlDbserver './modules/sql/main.bicep' = {
  name: 'DeploymySqlServer'
  params: {
    resourceGroupName: toUpper('RG-${sqlName}')
    flexibleSqlServerName: sqlName
    location: location
    tags: tags

    customTags: {
      workloadType: 'mySqlFlexibleServer'
    }
    skuName: 'Standard_B1s'
    SkuTier: 'Burstable'
    StorageSizeGB: 20
    StorageIops: 396
    peSubnetId: virtualNetwork.outputs.subnets.MySQLFlexSubnet.id
    privateDnsZoneName: 'privatelink.mysql.database.azure.com'
    sqlAdminUser: sqlAdmin
    sqlAdminPasword: sqlPassword
    mysqlVersion: '8.0.21'
    databaseName: 'redcapdb'
    database_charset: 'utf8'
    database_collation: 'utf8_general_ci'
    virtualNetworkId: virtualNetwork.outputs.virtualNetworkId
  }
}

module webApp './modules/webapp/main.bicep' = {
  name: 'webAppDeploy'
  params: {
    resourceGroupName: toUpper('RG-${webAppName}')
    webAppName: webAppName
    appServicePlan: 'ASP-${webAppName}'
    location: location
    skuName: 'S1'
    skuTier: 'Standard'
    peSubnetId: virtualNetwork.outputs.subnets.ComputeSubnet.id
    linuxFxVersion: 'php|8.2'
    tags: tags

    customTags: {
      workloadType: 'webApp'
    }
    privateDnsZoneName: 'privatelink.azurewebsites.net'
    virtualNetworkId: virtualNetwork.outputs.virtualNetworkId
    dbHostName: mysqlDbserver.outputs.databaseName
    dbName: mysqlDbserver.outputs.databaseName
    dbPassword: kvSecrets.outputs.keyVaultRefs[1]
    dbUserName: mysqlDbserver.outputs.sqlAdmin
  }
}
