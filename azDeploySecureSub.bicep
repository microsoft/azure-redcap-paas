targetScope = 'subscription'

@description('The Azure region to target for the deployment. Replaces {loc} in namingConvention.')
@allowed([
  'eastus'
  'westus'
])
param location string = 'eastus'

@description('The environment designator for the deployment. Replaces {env} in namingConvention.')
@allowed([
  'test'
  'demo'
  'prod'
])
param environment string = 'demo'
@description('The workload name. Replaces {workloadName} in namingConvention.')
param workloadName string = 'redcap'
@description('The Azure resource naming convention. Include the following placeholders (case-sensitive): {workloadName}, {env}, {rtype}, {loc}, {seq}.')
param namingConvention string = '{workloadName}-{env}-{rtype}-{loc}-{seq}'
@description('A sequence number for the deployment. Used to distinguish multiple deployed versions of the same workload. Replaces {seq} in namingConvention.')
param sequence int = 1

@description('A valid Entra ID object ID, which will be assigned RBAC permissions on the deployed resources.')
param identityObjectId string

var sequenceFormatted = format('{0:00}', sequence)
var rgNamingStructure = replace(replace(replace(replace(replace(namingConvention, '{rtype}', 'rg'), '{workloadName}', '${workloadName}-{rgName}'), '{loc}', location), '{seq}', sequenceFormatted), '{env}', environment)
var vnetName = nameModule[0].outputs.shortName
var strgName = nameModule[1].outputs.shortName
var webAppName = nameModule[2].outputs.shortName
var kvName = nameModule[3].outputs.shortName
var sqlName = nameModule[4].outputs.shortName
var planName = nameModule[5].outputs.shortName
var sqlAdmin = 'sqladmin'
var sqlPassword = 'P@ssw0rd' // TODO: this should be linked to keyvault secret.

var subnets = {
  // TODO: Define securityRules
  PrivateLinkSubnet: {
    // TODO: These need to become parameters. Ideally, a single VNet address space parameters and then use the CIDR functions to carve out subnets
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
    // TODO: /29 seems very small
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
    value: mySqlModule.outputs.sqlAdmin
  }
  {
    name: 'sqlPassword'
    value: sqlPassword
  }
  {
    name: 'dbHostName'
    value: mySqlModule.outputs.mySqlServerName
  }
  {
    name: 'dbName'
    value: mySqlModule.outputs.databaseName
  }
]

var workloads = [
  'vnet'
  'st'
  'webApp'
  'kv'
  'mysql'
  'plan'
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

module rolesModule './modules/common/roles.bicep' = {
  name: 'Roles'
}

module kvSecretReferencesModule './modules/common/appSvcKeyVaultRefs.bicep' = {
  name: 'secrets'
  params: {
    keyVaultName: kvName
    secretNames: secrets
  }
}

module virtualNetworkModule './modules/networking/main.bicep' = {
  name: 'vnetDeploy'
  params: {
    resourceGroupName: replace(rgNamingStructure, '{rgName}', 'network')
    virtualNetworkName: vnetName
    // TODO: Parameter
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

module storageAccountModule './modules/storage/main.bicep' = {
  name: 'strgDeploy'
  params: {
    resourceGroupName: replace(rgNamingStructure, '{rgName}', 'storage')
    location: location
    storageAccountName: strgName
    peSubnetId: virtualNetworkModule.outputs.subnets.PrivateLinkSubnet.id
    storageContainerName: 'redcap'
    kind: 'StorageV2'
    storageAccountSku: 'Standard_LRS'
    virtualNetworkId: virtualNetworkModule.outputs.virtualNetworkId
    privateDnsZoneName: 'privatelink.blob.${az.environment().suffixes.storage}'
    tags: tags
    customTags: {
      workloadType: 'storageAccount'
    }
  }
}

module keyVaultModule './modules/kv/main.bicep' = {
  name: 'kvDeploy'
  params: {
    resourceGroupName: replace(rgNamingStructure, '{rgName}', 'keyVault')
    keyVaultName: kvName
    location: location
    tags: tags
    customTags: {
      workloadType: 'keyVault'
    }
    peSubnetId: virtualNetworkModule.outputs.subnets.PrivateLinkSubnet.id
    virtualNetworkId: virtualNetworkModule.outputs.virtualNetworkId
    roleAssignments: [
      {
        RoleDefinitionId: rolesModule.outputs.roles['Key Vault Administrator']
        objectId: identityObjectId
      }
      {
        RoleDefinitionId: rolesModule.outputs.roles['Key Vault Secrets User']
        objectId: webAppModule.outputs.webAppIdentity
      }
    ]
    privateDnsZoneName: 'privatelink.vaultcore.azure.net'
    secrets: secrets
  }
}

module mySqlModule './modules/sql/main.bicep' = {
  name: 'DeploymySqlServer'
  params: {
    resourceGroupName: replace(rgNamingStructure, '{rgName}', 'mysql')
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
    peSubnetId: virtualNetworkModule.outputs.subnets.MySQLFlexSubnet.id
    privateDnsZoneName: 'privatelink.mysql.database.azure.com'
    sqlAdminUser: sqlAdmin
    sqlAdminPasword: sqlPassword
    mysqlVersion: '8.0.21'
    databaseName: 'redcapdb'
    database_charset: 'utf8'
    database_collation: 'utf8_general_ci'
    virtualNetworkId: virtualNetworkModule.outputs.virtualNetworkId
  }
}

module webAppModule './modules/webapp/main.bicep' = {
  name: 'webAppDeploy'
  params: {
    resourceGroupName: replace(rgNamingStructure, '{rgName}', 'web')
    webAppName: webAppName
    appServicePlan: planName
    location: location
    skuName: 'S1'
    skuTier: 'Standard'
    peSubnetId: virtualNetworkModule.outputs.subnets.ComputeSubnet.id
    linuxFxVersion: 'php|8.2'
    tags: tags

    customTags: {
      workloadType: 'webApp'
    }
    privateDnsZoneName: 'privatelink.azurewebsites.net'
    virtualNetworkId: virtualNetworkModule.outputs.virtualNetworkId
    dbHostName: mySqlModule.outputs.databaseName
    dbName: mySqlModule.outputs.databaseName
    dbPassword: kvSecretReferencesModule.outputs.keyVaultRefs[1]
    dbUserName: mySqlModule.outputs.sqlAdmin
  }
}

// TODO: Consider outputting the web app URL
