param location string
param tags object
param customTags object
param flexibleSqlServerName string
// TODO: Rename to integrationSubNetId
param peSubnetId string
param privateDnsZoneName string
param sqlAdminUser string
param virtualNetworkId string

@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

param existingPrivateDnsZonesResourceGroupId string = ''

param enableAzureVerifiedModulesTelemetry bool

@description('MySQL version')
@allowed([
  '8.0.21'
  '8.4'
  '9.3'
])
param mysqlVersion string

@secure()
param sqlAdminPassword string

@description('Azure database for MySQL sku name ')
param skuName string = 'Standard_B1ms'

@description('Azure database for MySQL pricing tier')
@allowed([
  'GeneralPurpose'
  'MemoryOptimized'
  'Burstable'
])
param SkuTier string

@allowed([
  'Enabled'
  'Disabled'
])
param highAvailability string = 'Disabled'

param availabilityZonesEnabled bool = false

@allowed([
  'Enabled'
  'Disabled'
])
@description('Whether or not geo redundant backup is enabled.')
param geoRedundantBackup string = 'Disabled'

@description('Azure database for MySQL storage Size ')
@minValue(32)
param StorageSizeGB int

@description('Azure database for MySQL storage Iops')
param StorageIops int

@minValue(1)
@maxValue(35)
param backupRetentionDays int = 7

param databaseName string
param database_charset string = 'utf8'
param database_collation string = 'utf8_general_ci'

param deploymentNameStructure string

var mergeTags = union(tags, customTags)

module flexibleServerModule 'br/public:avm/res/db-for-my-sql/flexible-server:0.10.1' = {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'db'), 64)
  params: {
    // Required parameters
    availabilityZone: -1
    name: flexibleSqlServerName
    skuName: skuName
    tier: SkuTier

    // Non-required parameters
    location: location
    version: mysqlVersion

    administratorLogin: sqlAdminUser
    administratorLoginPassword: sqlAdminPassword

    // Future use if REDCap can use managed identities to connect to the database
    // administrators: [
    //   {
    //     identityResourceId: '<identityResourceId>'
    //     login: '<login>'
    //     sid: '<sid>'
    //   }
    // ]
    // managedIdentities: {
    //   userAssignedResourceIds: [
    //     '<managedIdentityResourceId>'
    //   ]
    // }

    configurations: [
      {
        name: 'sql_generate_invisible_primary_key' // This might still fail with 8.0.21 versions
        value: 'OFF'
      }
      {
        name: 'max_allowed_packet'
        value: '1073741824' // 1 GB (1024^3 bytes)
      }
    ]

    backupRetentionDays: backupRetentionDays
    geoRedundantBackup: geoRedundantBackup

    databases: [
      {
        name: databaseName
        charset: database_charset
        collation: database_collation
      }
    ]

    delegatedSubnetResourceId: peSubnetId
    privateDnsZoneResourceId: empty(existingPrivateDnsZonesResourceGroupId)
      ? privateDns.?outputs.privateDnsId
      : '${existingPrivateDnsZonesResourceGroupId}/providers/Microsoft.Network/privateDnsZones/${privateDnsZoneName}'
    publicNetworkAccess: publicNetworkAccess

    highAvailability: (highAvailability == 'Enabled' && availabilityZonesEnabled)
      ? 'ZoneRedundant'
      : (highAvailability == 'Enabled') ? 'SameZone' : 'Disabled'
    storageAutoGrow: 'Enabled'
    storageAutoIoScaling: 'Enabled'
    storageIOPS: StorageIops
    storageSizeGB: StorageSizeGB

    // roleAssignments: [
    //   {
    //     principalId: uamiPrincipalId
    //     roleDefinitionIdOrName: roles.Contributor
    //   }
    // ]

    tags: mergeTags

    enableTelemetry: enableAzureVerifiedModulesTelemetry
  }
}

module privateDns '../pdns/main.bicep' = if (empty(existingPrivateDnsZonesResourceGroupId)) {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'mysql-dns'), 64)
  params: {
    privateDnsZoneName: privateDnsZoneName
    virtualNetworkId: virtualNetworkId
    tags: mergeTags
  }
}

output mySqlServerName string = flexibleServerModule.outputs.name // server.name
output databaseName string = databaseName
output sqlAdmin string = sqlAdminUser
output fqdn string = flexibleServerModule.outputs.fqdn
