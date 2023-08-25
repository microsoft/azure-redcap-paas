@description('Server Name for Azure database for MySQL')
param flexibleServerName string

param location string
param tags object

@description('Azure database for MySQL sku name ')
param skuName string = 'Standard_B1s'

@description('Azure database for MySQL pricing tier')
@allowed([
  'GeneralPurpose'
  'MemoryOptimized'
  'Burstable'
])
param SkuTier string = 'Burstable'

@description('Azure database for MySQL storage Size ')
param StorageSizeGB int = 20

@description('Azure database for MySQL storage Iops')
param StorageIops int = 360

param subnetId string
param privateDnsZone string

param adminUserName string

@description('Database administrator password')
@minLength(8)
@secure()
param adminPassword string

@description('MySQL version')
@allowed([
  '5.7'
  '8.0.21'
])
param mysqlVersion string = '8.0.21'

@allowed([
  'Enabled'
  'Disabled'
])
@description('Whether or not geo redundant backup is enabled.')
param geoRedundantBackup string = 'Disabled'

param backupRetentionDays int = 7

@allowed([
  'Enabled'
  'Disabled'
])
param highAvailability string = 'Disabled'

@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

param dbName string
param db_charset string = 'utf8'
param db_collation string = 'utf8_general_ci'

resource pDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZone
}

resource server 'Microsoft.DBforMySQL/flexibleServers@2022-09-30-preview' = {
  name: flexibleServerName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: SkuTier
  }
  properties: {
    administratorLogin: adminUserName
    administratorLoginPassword: adminPassword
    version: mysqlVersion
    replicationRole: 'None'
    createMode: 'Default'
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
    highAvailability: {
      mode: highAvailability
    }
    network: {
      delegatedSubnetResourceId: subnetId
      privateDnsZoneResourceId: pDnsZone.id
      publicNetworkAccess: publicNetworkAccess
    }
    storage: {
      autoGrow: 'Enabled'
      iops: StorageIops
      storageSizeGB: StorageSizeGB
    }
  }
}

resource database 'Microsoft.DBforMySQL/flexibleServers/databases@2021-12-01-preview' = {
  parent: server
  name: dbName
  properties: {
    charset: db_charset
    collation: db_collation
  }
}

output dbServerName string = server.name
output dbName string = database.name
