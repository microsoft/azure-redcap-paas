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
@minValue(1)
@maxValue(99)
param sequence int = 1

@description('A valid Entra ID object ID, which will be assigned RBAC permissions on the deployed resources.')
param identityObjectId string

@description('The address space for the virtual network. Subnets will be carved out. Minimum IPv4 size: /24.')
param vnetAddressSpace string
@description('If available, the public URL to download the REDCap zip file from. Used for debugging purposes. Does not need to be specified when downloading from the REDCap community using a username and password.')
@secure()
param redcapZipUrl string = ''
@description('REDCap Community site username for downloading the REDCap zip file.')
@secure()
param redcapCommunityUsername string

@description('REDCap Community site password for downloading the REDCap zip file.')
@secure()
param redcapCommunityPassword string

param deploymentTime string = utcNow()

@description('The password to use for the MySQL Flexible Server admin account \'sqladmin\'.')
@secure()
param sqlPassword string

param sqlAdmin string = 'sqladmin'

var sequenceFormatted = format('{0:00}', sequence)
var rgNamingStructure = replace(replace(replace(replace(replace(namingConvention, '{rtype}', 'rg'), '{workloadName}', '${workloadName}-{rgName}'), '{loc}', location), '{seq}', sequenceFormatted), '{env}', environment)
var vnetName = nameModule[0].outputs.shortName
var strgName = nameModule[1].outputs.shortName
var webAppName = nameModule[2].outputs.shortName
var kvName = nameModule[3].outputs.shortName
var sqlName = nameModule[4].outputs.shortName
var planName = nameModule[5].outputs.shortName
var uamiName = nameModule[6].outputs.shortName
var dplscrName = nameModule[7].outputs.shortName
var lawName = nameModule[8].outputs.shortName

var deploymentNameStructure = '${workloadName}-${environment}-${sequenceFormatted}-{rtype}-${deploymentTime}'

var subnets = {
  // TODO: Define securityRules
  PrivateLinkSubnet: {
    addressPrefix: cidrSubnet(vnetAddressSpace, 27, 0)
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
    addressPrefix: cidrSubnet(vnetAddressSpace, 27, 1)
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
    // Two /27 have already been created, which add up to a /26. This the second /26 (index = 1).
    addressPrefix: cidrSubnet(vnetAddressSpace, 26, 1)
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
    // Two /26 have been allocated; that's equivalent to sixteen /29s. 
    addressPrefix: cidrSubnet(vnetAddressSpace, 29, 16)
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
  {
    name: 'redcapCommunityUsername'
    value: redcapCommunityUsername
  }
  {
    name: 'redcapCommunityPassword'
    value: redcapCommunityPassword
  }
]

// TODO: Consider renaming to resourceTypes
var workloads = [
  'vnet'
  'st'
  'webApp'
  'kv'
  'mysql'
  'plan'
  'uami'
  'dplscr'
  'law'
]

@batchSize(1)
module nameModule 'modules/common/createValidAzResourceName.bicep' = [for workload in workloads: {
  name: take(replace(deploymentNameStructure, '{rtype}', 'nameGen-${workload}'), 64)
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
  name: take(replace(deploymentNameStructure, '{rtype}', 'roles'), 64)
}

module kvSecretReferencesModule './modules/common/appSvcKeyVaultRefs.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'kv-secrets'), 64)
  params: {
    keyVaultName: kvName
    secretNames: map(secrets, s => s.name)
  }
}

module virtualNetworkModule './modules/networking/main.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'network'), 64)
  params: {
    resourceGroupName: replace(rgNamingStructure, '{rgName}', 'network')
    virtualNetworkName: vnetName
    vnetAddressPrefix: vnetAddressSpace
    location: location
    subnets: subnets
    customDnsIPs: []
    tags: tags
    customTags: {
      workloadType: 'networking'
    }

    deploymentNameStructure: deploymentNameStructure
  }
}

module monitoring './modules/monitoring/main.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'monitoring'), 64)
  params: {
    resourceGroupName: replace(rgNamingStructure, '{rgName}', 'monitoring')
    appInsightsName: 'appInsights-${webAppName}'
    logAnalyticsWorkspaceName: lawName
    logAnalyticsWorkspaceSku: 'PerGB2018'
    retentionInDays: 30
    location: location
    tags: tags
    customTags: {
      workloadType: 'monitoring'
    }

    deploymentNameStructure: deploymentNameStructure
  }
}

module storageAccountModule './modules/storage/main.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'storage'), 64)
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

    deploymentNameStructure: deploymentNameStructure
  }
}

module keyVaultModule './modules/kv/main.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'keyVault'), 64)
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

    deploymentNameStructure: deploymentNameStructure
  }
}

module mySqlModule './modules/sql/main.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'mysql'), 64)
  params: {
    resourceGroupName: replace(rgNamingStructure, '{rgName}', 'database')
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
    // TODO: Consider using workloadname + 'db'
    databaseName: 'redcapdb'

    roles: rolesModule.outputs.roles
    uamiName: uamiName
    deploymentScriptName: dplscrName

    // Required charset and collation for REDCap
    database_charset: 'utf8'
    database_collation: 'utf8_general_ci'

    virtualNetworkId: virtualNetworkModule.outputs.virtualNetworkId

    deploymentNameStructure: deploymentNameStructure
  }
}

module webAppModule './modules/webapp/main.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'appService'), 64)
  params: {
    resourceGroupName: replace(rgNamingStructure, '{rgName}', 'web')
    webAppName: webAppName
    appServicePlanName: planName
    location: location
    // TODO: Consider deploying as P0V3 to ensure the deployment runs on a scale unit that supports P_v3 for future upgrades. GH issue #50
    skuName: 'S1'
    skuTier: 'Standard'
    peSubnetId: virtualNetworkModule.outputs.subnets.ComputeSubnet.id
    appInsights_connectionString: monitoring.outputs.appInsightsResourceId
    appInsights_instrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
    linuxFxVersion: 'php|8.2'
    tags: tags
    customTags: {
      workloadType: 'webApp'
    }
    privateDnsZoneName: 'privatelink.azurewebsites.net'
    virtualNetworkId: virtualNetworkModule.outputs.virtualNetworkId
    dbHostName: mySqlModule.outputs.fqdn
    dbName: mySqlModule.outputs.databaseName
    dbPasswordSecretRef: kvSecretReferencesModule.outputs.keyVaultRefs[1]
    dbUserNameSecretRef: kvSecretReferencesModule.outputs.keyVaultRefs[0]
    redcapZipUrl: redcapZipUrl
    redcapCommunityUsername: kvSecretReferencesModule.outputs.keyVaultRefs[4]
    redcapCommunityPassword: kvSecretReferencesModule.outputs.keyVaultRefs[5]
    // Enable VNet integration
    integrationSubnetId: virtualNetworkModule.outputs.subnets.IntegrationSubnet.id

    deploymentNameStructure: deploymentNameStructure
  }
}

// The web app URL
output webAppUrl string = webAppModule.outputs.webAppUrl
