param location string = resourceGroup().location
param storageContainerName string = ''
param peSubnetId string
param storageAccountName string

@description('privateDnsZone Details')
param privateDnsZoneId string

@description('storageAccountSku')
param storageAccountSku string

param tags object
param kind string

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
        name: 'pe-${storageAccountName}'
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

resource privateDnsZoneGroupsStorage 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = {
  name: 'default'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'pe-${storageAccountName}'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}
