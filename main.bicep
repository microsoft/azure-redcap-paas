targetScope = 'subscription'

@description('The Azure region to target for the deployment. Replaces {loc} in namingConvention.')
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
@description('Github Repo URL where build scripts are downloaded from')
param scmRepoUrl string = 'https://github.com/microsoft/azure-redcap-paas'
@description('Github Repo Branch where build scripts are downloaded from')
param scmRepoBranch string = 'main'
@description('The command before build to be run on the web app with an elevated privilege. This is used to install the required packages for REDCap operation.')
param prerequisiteCommand string = '/home/startup.sh'

param deploymentTime string = utcNow()

param enableAppServicePrivateEndpoint bool = true

@description('The password to use for the MySQL Flexible Server admin account \'sqladmin\'.')
@secure()
param sqlPassword string

@description('The MySQL Flexible Server admin user account name. Defaults to \'sqladmin\'.')
param sqlAdmin string = 'sqladmin'

@description('The outgoing SMTP server FQDN or IP address.')
param smtpFQDN string = ''
@description('The outgoing SMTP server port.')
param smtpPort string = ''
@description('The email address to use as the sender for outgoing emails.')
param smtpFromEmailAddress string = ''

param existingPrivateDnsZonesResourceGroupId string = ''
param existingVirtualNetworkId string = ''

var sequenceFormatted = format('{0:00}', sequence)
var rgNamingStructure = replace(
  replace(
    replace(
      replace(replace(namingConvention, '{rtype}', 'rg'), '{workloadName}', '${workloadName}-{rgName}'),
      '{loc}',
      location
    ),
    '{seq}',
    sequenceFormatted
  ),
  '{env}',
  environment
)
// The name of the VNet is either a new name or the name of the existing VNet parsed from the resource ID
var vnetName = empty(existingVirtualNetworkId)
  ? nameModule[0].outputs.shortName
  : split(existingVirtualNetworkId, '/')[8]

var strgName = nameModule[1].outputs.shortName
var webAppName = nameModule[2].outputs.shortName
var kvName = nameModule[3].outputs.shortName
var sqlName = nameModule[4].outputs.shortName
var planName = nameModule[5].outputs.shortName
var uamiName = nameModule[6].outputs.shortName
var dplscrName = nameModule[7].outputs.shortName
var lawName = nameModule[8].outputs.shortName

var deploymentNameStructure = '${workloadName}-${environment}-${sequenceFormatted}-{rtype}-${deploymentTime}'

// TODO: Define type
param subnets object = {
  // TODO: Define securityRules
  // TODO: Add existingSubnetName property for existing subnet
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

var secrets = {
  sqlAdminName: mySqlModule.outputs.sqlAdmin
  sqlPassword: sqlPassword
  redcapCommunityUsername: redcapCommunityUsername
  redcapCommunityPassword: redcapCommunityPassword
}

var resourceTypes = [
  'vnet'
  'st'
  'app'
  'kv'
  'mysql'
  'plan'
  'uami'
  'dplscr'
  'law'
]

@batchSize(1)
module nameModule 'modules/common/createValidAzResourceName.bicep' = [
  for workload in resourceTypes: {
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
  }
]

module rolesModule './modules/common/roles.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'roles'), 64)
}

var storageAccountKeySecretName = 'storageKey'
// The secrets object is converted to an array using the items() function, which alphabetically sorts it
var defaultSecretNames = map(items(secrets), s => s.key)
var additionalSecretNames = [storageAccountKeySecretName]
var secretNames = concat(defaultSecretNames, additionalSecretNames)

// The output will be in alphabetical order
// LATER: Output an object instead
module kvSecretReferencesModule './modules/common/appSvcKeyVaultRefs.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'kv-secrets'), 64)
  params: {
    keyVaultName: kvName
    secretNames: secretNames
  }
}

module virtualNetworkModule './modules/networking/main.bicep' = if (empty(existingVirtualNetworkId)) {
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

var privateEndpointSubnetId = empty(existingVirtualNetworkId)
  ? virtualNetworkModule.outputs.subnets.PrivateLinkSubnet.id
  : '${existingVirtualNetworkId}/subnets/${subnets.PrivateLinkSubnet.existingSubnetName}'

var virtualNetworkId = empty(existingVirtualNetworkId)
  ? virtualNetworkModule.outputs.virtualNetworkId
  : existingVirtualNetworkId

module storageAccountModule './modules/storage/main.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'storage'), 64)
  params: {
    resourceGroupName: replace(rgNamingStructure, '{rgName}', 'storage')
    location: location
    storageAccountName: strgName
    peSubnetId: privateEndpointSubnetId
    storageContainerName: 'redcap'
    kind: 'StorageV2'
    storageAccountSku: 'Standard_LRS'

    virtualNetworkId: virtualNetworkId
    privateDnsZoneName: 'privatelink.blob.${az.environment().suffixes.storage}'
    existingPrivateDnsZonesResourceGroupId: existingPrivateDnsZonesResourceGroupId

    tags: tags
    customTags: {
      workloadType: 'storageAccount'
    }

    deploymentNameStructure: deploymentNameStructure

    keyVaultSecretName: storageAccountKeySecretName
    keyVaultId: keyVaultModule.outputs.id
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
    peSubnetId: privateEndpointSubnetId
    virtualNetworkId: virtualNetworkId
    existingPrivateDnsZonesResourceGroupId: existingPrivateDnsZonesResourceGroupId
    roleAssignments: [
      {
        RoleDefinitionId: rolesModule.outputs.roles['Key Vault Administrator']
        objectId: identityObjectId
      }
      {
        RoleDefinitionId: rolesModule.outputs.roles['Key Vault Secrets User']
        objectId: uamiModule.outputs.principalId
        principtalType: 'ServicePrincipal'
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
    skuName: 'Standard_B1ms'
    SkuTier: 'Burstable'
    StorageSizeGB: 20
    StorageIops: 396
    peSubnetId: empty(existingVirtualNetworkId)
      ? virtualNetworkModule.outputs.subnets.MySQLFlexSubnet.id
      : '${existingVirtualNetworkId}/subnets/${subnets.MySQLFlexSubnet.existingSubnetName}'
    privateDnsZoneName: 'privatelink.mysql.database.azure.com'
    existingPrivateDnsZonesResourceGroupId: existingPrivateDnsZonesResourceGroupId
    sqlAdminUser: sqlAdmin
    sqlAdminPasword: sqlPassword
    mysqlVersion: '8.0.21'
    // TODO: Consider using workloadname + 'db'
    databaseName: 'redcapdb'

    roles: rolesModule.outputs.roles

    uamiId: uamiModule.outputs.id
    uamiPrincipalId: uamiModule.outputs.principalId

    deploymentScriptName: dplscrName

    // Required charset and collation for REDCap
    database_charset: 'utf8'
    database_collation: 'utf8_general_ci'

    virtualNetworkId: virtualNetworkId

    deploymentNameStructure: deploymentNameStructure
  }
}

resource webAppResourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: replace(rgNamingStructure, '{rgName}', 'web')
  location: location
  tags: union(tags, {
    workloadType: 'web'
  })
}

module webAppModule './modules/webapp/main.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'appService'), 64)
  scope: webAppResourceGroup
  params: {
    webAppName: webAppName
    appServicePlanName: planName
    location: location
    // Deploy as P0V3 to ensure the deployment runs on a scale unit that supports P_v3 for future upgrades. GH issue #50
    skuName: 'P0V3'
    peSubnetId: privateEndpointSubnetId
    appInsights_connectionString: monitoring.outputs.appInsightsResourceId
    appInsights_instrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
    linuxFxVersion: 'php|8.2'
    tags: tags
    customTags: {
      workloadType: 'webApp'
    }

    existingPrivateDnsZonesResourceGroupId: existingPrivateDnsZonesResourceGroupId
    privateDnsZoneName: 'privatelink.azurewebsites.net'
    virtualNetworkId: virtualNetworkId

    redcapZipUrl: redcapZipUrl
    dbHostName: mySqlModule.outputs.fqdn
    dbName: mySqlModule.outputs.databaseName

    dbUserNameSecretRef: kvSecretReferencesModule.outputs.keyVaultRefs[2]
    dbPasswordSecretRef: kvSecretReferencesModule.outputs.keyVaultRefs[3]

    redcapCommunityUsernameSecretRef: kvSecretReferencesModule.outputs.keyVaultRefs[1]
    redcapCommunityPasswordSecretRef: kvSecretReferencesModule.outputs.keyVaultRefs[0]

    storageAccountKeySecretRef: kvSecretReferencesModule.outputs.keyVaultRefs[4]
    storageAccountContainerName: storageAccountModule.outputs.containerName
    storageAccountName: storageAccountModule.outputs.name

    // Enable VNet integration
    integrationSubnetId: empty(existingVirtualNetworkId)
      ? virtualNetworkModule.outputs.subnets.IntegrationSubnet.id
      : '${existingVirtualNetworkId}/subnets/${subnets.IntegrationSubnet.existingSubnetName}'

    scmRepoUrl: scmRepoUrl
    scmRepoBranch: scmRepoBranch
    prerequisiteCommand: prerequisiteCommand

    smtpFQDN: smtpFQDN
    smtpFromEmailAddress: smtpFromEmailAddress
    smtpPort: smtpPort

    deploymentNameStructure: deploymentNameStructure

    uamiId: uamiModule.outputs.id

    enablePrivateEndpoint: enableAppServicePrivateEndpoint
  }
}

module uamiModule 'modules/uami/main.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'uami'), 64)
  scope: webAppResourceGroup
  params: {
    tags: tags
    location: location
    uamiName: uamiName
  }
}

// // The web app URL
output webAppUrl string = webAppModule.outputs.webAppUrl
