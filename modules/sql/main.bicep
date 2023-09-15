targetScope = 'subscription'

param resourceGroupName string
param location string
param tags object
param customTags object
param flexibleSqlServerName string
param peSubnetId string
param privateDnsZoneName string
param sqlAdminUser string
param virtualNetworkId string

param roles object
param uamiName string
param deploymentScriptName string

@description('MySQL version')
@allowed([
  '5.7'
  '8.0.21'
  //'8.0.32'
])
param mysqlVersion string = '8.0.21'

@secure()
param sqlAdminPasword string

@description('Azure database for MySQL sku name ')
param skuName string = 'Standard_B1s'

@description('Azure database for MySQL pricing tier')
@allowed([
  'GeneralPurpose'
  'MemoryOptimized'
  'Burstable'
])
param SkuTier string

@description('Azure database for MySQL storage Size ')
param StorageSizeGB int = 20

@description('Azure database for MySQL storage Iops')
param StorageIops int = 360

param databaseName string
param database_charset string = 'utf8'
param database_collation string = 'utf8_general_ci'

var mergeTags = union(tags, customTags)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: mergeTags
}

module mysqlDbserver './sql.bicep' = {
  name: 'deploy-${flexibleSqlServerName}'
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
    privateDnsZoneId: privateDns.outputs.privateDnsId
    adminUserName: sqlAdminUser
    adminPassword: sqlAdminPasword
    mysqlVersion: mysqlVersion
    databaseName: databaseName
    database_charset: database_charset
    database_collation: database_collation

    roles: roles
    uamiName: uamiName
    deploymentScriptName: deploymentScriptName
  }
}

module privateDns '../pdns/main.bicep' = {
  name: 'deploy-peDns'
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
