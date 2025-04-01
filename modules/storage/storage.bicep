param location string = resourceGroup().location
param storageContainerName string = ''
param peSubnetId string
param storageAccountName string

@description('privateDnsZone Details')
param privateDnsZoneId string

@description('storageAccountSku')
param storageAccountSku string

@description('Resource ID of the Key Vault where the storage key secret should be created.')
param keyVaultId string
@description('Name of the secret in Key Vault.')
param keyVaultSecretName string

param tags object
param deploymentNameStructure string
param kind string
param minTlsVersion string = 'TLS1_2'

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
    minimumTlsVersion: minTlsVersion

    encryption: { requireInfrastructureEncryption: true }
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

// Create a secret with the storage account's primary key in the specified Key Vault
var keyVaultIdSplit = split(keyVaultId, '/')
var keyVaultResourceGroupName = keyVaultIdSplit[4]
var keyVaultName = keyVaultIdSplit[8]

resource keyVaultResourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: keyVaultResourceGroupName
  scope: subscription()
}

module keyVaultSecretsModule '../kv/kvSecrets.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'kv-st-secret'), 64)
  scope: keyVaultResourceGroup
  params: {
    keyVaultName: keyVaultName
    secrets: {
      '${keyVaultSecretName}': storageAccount.listKeys().keys[0].value
    }
  }
}

output name string = storageAccount.name
output id string = storageAccount.id
output containerName string = storageContainer.name
