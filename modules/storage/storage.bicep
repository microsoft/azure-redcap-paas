param location string = resourceGroup().location
param storageContainerName string = ''
param peSubnetId string
param storageAccountName string

@description('privateDnsZones Details')
param privateDNSZones array

@description('storageAccountSku')
param storageAccountSku string

param tags object
param kind string
//param accessTier string

var storageType = kind == 'FileStorage' ? 'file' : 'blob'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountSku
  }
  tags: tags
  kind: kind
  properties: {
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Disabled'
    //accessTier: accessTier
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = if (kind == 'StorageV2') {
  name: 'default'
  parent: storageAccount
}

resource storageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = if (kind == 'StorageV2') {
  name: storageContainerName
  parent: blobServices
}

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = if (kind == 'FileStorage') {
  name: 'default'
  parent: storageAccount
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = if (kind == 'FileStorage') {
  name: storageContainerName
  parent: fileServices
  properties: {
    accessTier: 'Premium'
    shareQuota: 100
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: 'pe-${storageAccountName}'
  location: location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${storageContainerName}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            storageType
          ]
        }
      }
    ]
  }
}

@batchSize(1)
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = [for (privateDnsZone, i) in privateDNSZones: {
  name: privateDnsZone
}]

resource privateDnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = [for (pzone, i) in privateDNSZones: {
  name: 'privatednsgroup-${storageType}${i}'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-${storageType}${i}'
        properties: {
          privateDnsZoneId: privateDnsZone[i].id
        }
      }
    ]
  }
}]
