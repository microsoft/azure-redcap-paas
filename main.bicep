targetScope = 'subscription'

@description('The Azure region to target for the deployment. Replaces {loc} in namingConvention.')
param location string = 'eastus'

@description('The environment designator for the deployment. Replaces {env} in namingConvention.')
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
param identityObjectId string = deployer().objectId

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
@description('The version of REDCap to download from the REDCap Community. This is not used when specifying a ZIP URL.')
param redcapVersion string = ''
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

@description('Whether High Availability is enabled for the MySQL Flexible Server. Zone redundant or same zone HA is determined by the value of availabilityZonesEnabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param mySqlHighAvailability string = 'Disabled'

param mySqlSkuName string = 'Standard_B1ms'

@allowed([
  'GeneralPurpose'
  'MemoryOptimized'
  'Burstable'
])
param mySqlSkuTier string = 'Burstable'
@description('The size of the MySQL Flexible Server storage in GB. This cannot be scaled down after server creation.')
@minValue(32)
param mySqlStorageSizeGB int = 32
param mySqlStorageIops int = 396

@description('The MySQL Flexible Server admin user account name. Defaults to \'sqladmin\'.')
param sqlAdmin string = 'sqladmin'

param appServiceSkuName string = 'P0v3'

@description('Determines whether availability zone redundancy is enabled for the MySQL Flexible Server and the app service. The region must support availability zones.')
param availabilityZonesEnabled bool = false
param existingPrivateDnsZonesResourceGroupId string = ''
param existingVirtualNetworkId string = ''

param appServiceTimeZone string = 'UTC'

@description('If true, the deployment will create all resources in a single resource group. If false, resources will be distributed across multiple resource groups according to their type.')
param singleResourceGroupDeployment bool = false

@description('If true, telemetry will be sent to Microsoft to help improve Azure Verified Modules. See https://azure.github.io/Azure-Verified-Modules/help-support/telemetry/ for more information.')
param enableAzureVerifiedModulesTelemetry bool = true

@description('The subnets in the REDCap virtual network. Leave default for most purposes. This parameter must be used when integrating with an existing virtual network, and the existing subnet names must be specified using the existingSubnetName property.')
// TODO: Define type
param subnets object = {
  // TODO: Define securityRules
  // TODO: Add existingSubnetName property for existing subnet
  PrivateLinkSubnet: {
    addressPrefix: cidrSubnet(vnetAddressSpace, 27, 0)
  }
  ComputeSubnet: {
    addressPrefix: cidrSubnet(vnetAddressSpace, 27, 1)
  }
  IntegrationSubnet: {
    // Two /27 have already been created, which add up to a /26. This the second /26 (index = 1).
    addressPrefix: cidrSubnet(vnetAddressSpace, 26, 1)
    delegation: 'Microsoft.Web/serverFarms'
  }
  MySQLFlexSubnet: {
    // TODO: /29 seems very small
    // Two /26 have been allocated; that's equivalent to sixteen /29s.
    addressPrefix: cidrSubnet(vnetAddressSpace, 29, 16)
    delegation: 'Microsoft.DBforMySQL/flexibleServers'
  }
}

////////////////////////////////////////////////////////////////////////////////
// VARIABLES
////////////////////////////////////////////////////////////////////////////////

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
//var dplscrName = nameModule[7].outputs.shortName
var lawName = nameModule[8].outputs.shortName

var deploymentNameStructure = '${workloadName}-${environment}-${sequenceFormatted}-{rtype}-${deploymentTime}'

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

var resourceGroupNames = {
  network: replace(rgNamingStructure, '{rgName}', 'network')
  storage: replace(rgNamingStructure, '{rgName}', 'storage')
  keyVault: replace(rgNamingStructure, '{rgName}', 'keyVault')
  database: replace(rgNamingStructure, '{rgName}', 'database')
  monitoring: replace(rgNamingStructure, '{rgName}', 'monitoring')
  web: replace(rgNamingStructure, '{rgName}', 'web')
  // If deploying to a single resource group, remove the '-{rgName}' placeholder and the leading hyphen.
  single: replace(rgNamingStructure, '-{rgName}', '')
}

////////////////////////////////////////////////////////////////////////////////
// HELPER MODULES
////////////////////////////////////////////////////////////////////////////////

@batchSize(1)
module nameModule 'modules/common/createValidAzResourceName.bicep' = [
  for workload in resourceTypes: {
    #disable-next-line BCP334
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
  #disable-next-line BCP334
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
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'kv-secrets'), 64)
  params: {
    keyVaultName: kvName
    secretNames: secretNames
  }
}

////////////////////////////////////////////////////////////////////////////////
// RESOURCE GROUPS
////////////////////////////////////////////////////////////////////////////////

module singleResourceGroupModule 'br/public:avm/res/resources/resource-group:0.4.3' = if (singleResourceGroupDeployment) {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'single-rg'), 64)
  params: {
    name: resourceGroupNames.single
    location: location
    tags: tags
  }
}

module networkResourceGroupModule 'br/public:avm/res/resources/resource-group:0.4.3' = if (!singleResourceGroupDeployment) {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'network-rg'), 64)
  params: {
    name: resourceGroupNames.network
    location: location
    tags: union(tags, {
      workloadType: 'networking'
    })
  }
}

module monitoringResourceGroupModule 'br/public:avm/res/resources/resource-group:0.4.3' = if (!singleResourceGroupDeployment) {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'monitoring-rg'), 64)
  params: {
    name: resourceGroupNames.monitoring
    location: location
    tags: union(tags, {
      workloadType: 'monitoring'
    })
  }
}

module storageResourceGroupModule 'br/public:avm/res/resources/resource-group:0.4.3' = if (!singleResourceGroupDeployment) {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'storage-rg'), 64)
  params: {
    name: resourceGroupNames.storage
    location: location
    tags: union(tags, {
      workloadType: 'storage'
    })
  }
}

module keyVaultResourceGroupModule 'br/public:avm/res/resources/resource-group:0.4.3' = if (!singleResourceGroupDeployment) {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'kv-rg'), 64)
  params: {
    name: resourceGroupNames.keyVault
    location: location
    tags: union(tags, {
      workloadType: 'keyVault'
    })
  }
}

module databaseResourceGroupModule 'br/public:avm/res/resources/resource-group:0.4.3' = if (!singleResourceGroupDeployment) {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'database-rg'), 64)
  params: {
    name: resourceGroupNames.database
    location: location
    tags: union(tags, {
      workloadType: 'database'
    })
  }
}

module webAppResourceGroupModule 'br/public:avm/res/resources/resource-group:0.4.3' = if (!singleResourceGroupDeployment) {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'web-rg'), 64)
  params: {
    name: resourceGroupNames.web
    location: location
    tags: union(tags, {
      workloadType: 'web'
    })
  }
}

////////////////////////////////////////////////////////////////////////////////
// RESOURCE MODULES
////////////////////////////////////////////////////////////////////////////////

module virtualNetworkModule './modules/networking/main.bicep' = if (empty(existingVirtualNetworkId)) {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'network'), 64)
  scope: resourceGroup(singleResourceGroupDeployment ? resourceGroupNames.single : resourceGroupNames.network)
  params: {
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
  dependsOn: [singleResourceGroupModule, networkResourceGroupModule]
}

module monitoring './modules/monitoring/main.bicep' = {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'monitoring'), 64)
  scope: resourceGroup(singleResourceGroupDeployment ? resourceGroupNames.single : resourceGroupNames.monitoring)
  params: {
    appInsightsName: 'appInsights-${webAppName}' // TODO: consistency
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
  dependsOn: [singleResourceGroupModule, monitoringResourceGroupModule]
}

var privateEndpointSubnetId = empty(existingVirtualNetworkId)
  ? virtualNetworkModule.?outputs.subnets.PrivateLinkSubnet.id
  : '${existingVirtualNetworkId}/subnets/${subnets.PrivateLinkSubnet.existingSubnetName}'

var virtualNetworkId = empty(existingVirtualNetworkId)
  ? virtualNetworkModule.?outputs.virtualNetworkId
  : existingVirtualNetworkId

module storageAccountModule './modules/storage/main.bicep' = {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'storage'), 64)
  scope: resourceGroup(singleResourceGroupDeployment ? resourceGroupNames.single : resourceGroupNames.storage)
  params: {
    location: location
    storageAccountName: strgName
    peSubnetId: privateEndpointSubnetId
    storageContainerName: 'redcap'
    kind: 'StorageV2'
    storageAccountSku: 'Standard_LRS'

    virtualNetworkId: virtualNetworkId!
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
  dependsOn: [singleResourceGroupModule, storageResourceGroupModule]
}

module keyVaultModule './modules/kv/main.bicep' = {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'keyVault'), 64)
  scope: resourceGroup(singleResourceGroupDeployment ? resourceGroupNames.single : resourceGroupNames.keyVault)
  params: {
    keyVaultName: kvName
    location: location
    tags: tags
    customTags: {
      workloadType: 'keyVault'
    }
    peSubnetId: privateEndpointSubnetId
    virtualNetworkId: virtualNetworkId!
    existingPrivateDnsZonesResourceGroupId: existingPrivateDnsZonesResourceGroupId
    roleAssignments: [
      {
        RoleDefinitionId: rolesModule.outputs.roles['Key Vault Administrator']
        objectId: identityObjectId
      }
      {
        RoleDefinitionId: rolesModule.outputs.roles['Key Vault Secrets User']
        objectId: uamiModule.outputs.principalId
        principalType: 'ServicePrincipal'
      }
    ]
    privateDnsZoneName: 'privatelink.vaultcore.azure.net'
    secrets: secrets

    deploymentNameStructure: deploymentNameStructure
  }
  dependsOn: [singleResourceGroupModule, keyVaultResourceGroupModule]
}

module mySqlModule './modules/sql/main.bicep' = {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'mysql'), 64)
  scope: resourceGroup(singleResourceGroupDeployment ? resourceGroupNames.single : resourceGroupNames.database)
  params: {
    flexibleSqlServerName: sqlName
    location: location
    tags: tags

    customTags: {
      workloadType: 'mySqlFlexibleServer'
    }
    skuName: mySqlSkuName
    SkuTier: mySqlSkuTier
    StorageSizeGB: mySqlStorageSizeGB
    StorageIops: mySqlStorageIops
    peSubnetId: empty(existingVirtualNetworkId)
      ? virtualNetworkModule.?outputs.subnets.MySQLFlexSubnet.id
      : '${existingVirtualNetworkId}/subnets/${subnets.MySQLFlexSubnet.existingSubnetName}'
    privateDnsZoneName: 'privatelink.mysql.database.azure.com'
    existingPrivateDnsZonesResourceGroupId: existingPrivateDnsZonesResourceGroupId
    sqlAdminUser: sqlAdmin
    sqlAdminPassword: sqlPassword
    mysqlVersion: '8.4'
    // TODO: Consider using workload name + 'db'
    databaseName: 'redcapdb'

    highAvailability: mySqlHighAvailability
    availabilityZonesEnabled: availabilityZonesEnabled

    // Required charset and collation for REDCap
    database_charset: 'utf8'
    database_collation: 'utf8_general_ci'

    virtualNetworkId: virtualNetworkId!

    deploymentNameStructure: deploymentNameStructure
    enableAzureVerifiedModulesTelemetry: enableAzureVerifiedModulesTelemetry
  }
  dependsOn: [singleResourceGroupModule, databaseResourceGroupModule]
}

module webAppModule './modules/webapp/main.bicep' = {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'appService'), 64)
  scope: resourceGroup(singleResourceGroupDeployment ? resourceGroupNames.single : resourceGroupNames.web)
  params: {
    webAppName: webAppName
    appServicePlanName: planName
    location: location
    skuName: appServiceSkuName
    peSubnetId: privateEndpointSubnetId
    appInsights_connectionString: monitoring.outputs.appInsightsResourceId
    appInsights_instrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
    linuxFxVersion: 'php|8.4'
    tags: tags
    customTags: {
      workloadType: 'webApp'
    }

    existingPrivateDnsZonesResourceGroupId: existingPrivateDnsZonesResourceGroupId
    privateDnsZoneName: 'privatelink.azurewebsites.net'
    virtualNetworkId: virtualNetworkId!

    redcapZipUrl: redcapZipUrl
    dbHostName: mySqlModule.outputs.fqdn
    dbName: mySqlModule.outputs.databaseName

    dbUserNameSecretRef: kvSecretReferencesModule.outputs.keyVaultRefs[2]
    dbPasswordSecretRef: kvSecretReferencesModule.outputs.keyVaultRefs[3]

    redcapCommunityUsernameSecretRef: kvSecretReferencesModule.outputs.keyVaultRefs[1]
    redcapCommunityPasswordSecretRef: kvSecretReferencesModule.outputs.keyVaultRefs[0]
    redcapVersion: redcapVersion

    storageAccountKeySecretRef: kvSecretReferencesModule.outputs.keyVaultRefs[4]
    storageAccountContainerName: storageAccountModule.outputs.containerName
    storageAccountName: storageAccountModule.outputs.name

    // Enable VNet integration
    integrationSubnetId: empty(existingVirtualNetworkId)
      ? virtualNetworkModule.?outputs.subnets.IntegrationSubnet.id
      : '${existingVirtualNetworkId}/subnets/${subnets.IntegrationSubnet.existingSubnetName}'

    scmRepoUrl: scmRepoUrl
    scmRepoBranch: scmRepoBranch
    prerequisiteCommand: prerequisiteCommand

    deploymentNameStructure: deploymentNameStructure

    uamiId: uamiModule.outputs.id

    availabilityZonesEnabled: availabilityZonesEnabled
    enablePrivateEndpoint: enableAppServicePrivateEndpoint

    timeZone: appServiceTimeZone
  }
  dependsOn: [singleResourceGroupModule, webAppResourceGroupModule]
}

module uamiModule 'modules/uami/main.bicep' = {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'uami'), 64)
  scope: resourceGroup(singleResourceGroupDeployment ? resourceGroupNames.single : resourceGroupNames.web)
  params: {
    tags: tags
    location: location
    uamiName: uamiName
  }
}

// The web app URL
output webAppUrl string = webAppModule.outputs.webAppUrl
