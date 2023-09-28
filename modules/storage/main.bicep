targetScope = 'subscription'

param resourceGroupName string
param location string
param storageAccountName string
param storageContainerName string
param kind string
param storageAccountSku string
param privateDnsZoneName string
param peSubnetId string
param virtualNetworkId string
param tags object
param customTags object

param deploymentNameStructure string

@description('Resource ID of the Key Vault where the storage key secret should be created.')
param keyVaultId string
@description('Name of the secret in Key Vault.')
param keyVaultSecretName string

var mergeTags = union(tags, customTags)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: mergeTags
}

module storageAccount './storage.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'st'), 64)
  scope: resourceGroup
  params: {
    location: location
    tags: mergeTags
    storageAccountName: storageAccountName
    peSubnetId: peSubnetId
    storageContainerName: storageContainerName
    kind: kind
    storageAccountSku: storageAccountSku
    privateDnsZoneId: privateDns.outputs.privateDnsId
    keyVaultId: keyVaultId
    keyVaultSecretName: keyVaultSecretName
    deploymentNameStructure: deploymentNameStructure
  }
}

module privateDns '../pdns/main.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'st-dns'), 64)
  scope: resourceGroup
  params: {
    privateDnsZoneName: privateDnsZoneName
    virtualNetworkId: virtualNetworkId
    tags: tags
  }
}

// TODO: Add lock to storage account to avoid accidental deletion

output id string = storageAccount.outputs.id
output name string = storageAccount.outputs.name
output resourceGroupName string = resourceGroup.name
output containerName string = storageAccount.outputs.containerName
