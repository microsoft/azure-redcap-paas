targetScope = 'subscription'

param resourceGroupName string
param location string
param tags object
param customTags object
param flexibleSqlServerName string
// TODO: Rename to integrationSubNetId
param peSubnetId string
param privateDnsZoneName string
param sqlAdminUser string
param virtualNetworkId string

param existingPrivateDnsZonesResourceGroupId string = ''

param roles object
param deploymentScriptName string

@description('MySQL version')
@allowed([
  '8.0.21'
])
param mysqlVersion string = '8.0.21'

@secure()
param sqlAdminPasword string

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

@description('Azure database for MySQL storage Size ')
param StorageSizeGB int = 20

@description('Azure database for MySQL storage Iops')
param StorageIops int = 360

param databaseName string
param database_charset string = 'utf8'
param database_collation string = 'utf8_general_ci'

param uamiId string
param uamiPrincipalId string

param deploymentNameStructure string

var mergeTags = union(tags, customTags)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: mergeTags
}

module mysqlDbserver './sql.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'mysql'), 64)
  scope: resourceGroup
  params: {
    flexibleSqlServerName: flexibleSqlServerName
    location: location
    tags: mergeTags
    skuName: skuName
    SkuTier: SkuTier
    StorageSizeGB: StorageSizeGB
    StorageIops: StorageIops
    peSubnetId: peSubnetId
    privateDnsZoneId: empty(existingPrivateDnsZonesResourceGroupId)
      ? privateDns.outputs.privateDnsId
      : '${existingPrivateDnsZonesResourceGroupId}/providers/Microsoft.Network/privateDnsZones/${privateDnsZoneName}'
    adminUserName: sqlAdminUser
    adminPassword: sqlAdminPasword
    mysqlVersion: mysqlVersion
    databaseName: databaseName
    database_charset: database_charset
    database_collation: database_collation

    highAvailability: (highAvailability == 'Enabled') ? true : false
    availabilityZonesEnabled: availabilityZonesEnabled

    roles: roles
    uamiId: uamiId
    uamiPrincipalId: uamiPrincipalId
    deploymentScriptName: deploymentScriptName
  }
}

module privateDns '../pdns/main.bicep' = if (empty(existingPrivateDnsZonesResourceGroupId)) {
  name: take(replace(deploymentNameStructure, '{rtype}', 'mysql-dns'), 64)
  scope: resourceGroup
  params: {
    privateDnsZoneName: privateDnsZoneName
    virtualNetworkId: virtualNetworkId
    tags: tags
  }
}

output mySqlServerName string = mysqlDbserver.outputs.mySqlServerName
output databaseName string = mysqlDbserver.outputs.databaseName
output sqlAdmin string = mysqlDbserver.outputs.sqlAdmin
output fqdn string = mysqlDbserver.outputs.fqdn
