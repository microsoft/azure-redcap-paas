@description('Server Name for Azure database for MySQL')
param flexibleSqlServerName string

param location string
param tags object

// TODO: skuName and SkuTier are related; should be specified as a single object param, IMHO
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

param peSubnetId string
param privateDnsZoneId string

param adminUserName string

param roles object
param uamiName string
param deploymentScriptName string

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

param databaseName string
param database_charset string = 'utf8'
param database_collation string = 'utf8_general_ci'

param currentTime string = utcNow()

resource server 'Microsoft.DBforMySQL/flexibleServers@2022-09-30-preview' = {
  name: flexibleSqlServerName
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
      delegatedSubnetResourceId: peSubnetId
      privateDnsZoneResourceId: privateDnsZoneId
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
  name: databaseName
  properties: {
    charset: database_charset
    collation: database_collation
  }
}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: uamiName
  location: location
  tags: tags
}

module uamiMySqlRoleAssignmentModule '../common/roleAssignment-mySql.bicep' = {
  name: 'mySqlRole'
  params: {
    mySqlFlexServerName: server.name
    principalId: uami.properties.principalId
    roleDefinitionId: roles.Contributor
  }
}

resource dbConfigDeploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: deploymentScriptName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.50.0'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    forceUpdateTag: currentTime
    scriptContent: 'az mysql flexible-server parameter set -g ${resourceGroup().name} --server-name ${server.name} --name sql_generate_invisible_primary_key --value OFF'
  }
  tags: tags
  dependsOn: [ uamiMySqlRoleAssignmentModule ]
}

output mySqlServerName string = server.name
output databaseName string = database.name
output sqlAdmin string = server.properties.administratorLogin
output fqdn string = server.properties.fullyQualifiedDomainName
