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

param existingPrivateDnsZonesResourceGroupId string

param deploymentNameStructure string

@description('Resource ID of the Key Vault where the storage key secret should be created.')
param keyVaultId string
@description('Name of the secret in Key Vault.')
param keyVaultSecretName string

var mergeTags = union(tags, customTags)

module storageAccount './storage.bicep' = {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'st'), 64)
  params: {
    location: location
    tags: mergeTags
    storageAccountName: storageAccountName
    peSubnetId: peSubnetId
    storageContainerName: storageContainerName
    kind: kind
    storageAccountSku: storageAccountSku
    privateDnsZoneId: empty(existingPrivateDnsZonesResourceGroupId)
      ? privateDns.?outputs.privateDnsId!
      : '${existingPrivateDnsZonesResourceGroupId}/providers/Microsoft.Network/privateDnsZones/${privateDnsZoneName}'
    keyVaultId: keyVaultId
    keyVaultSecretName: keyVaultSecretName
    deploymentNameStructure: deploymentNameStructure
  }
}

module privateDns '../pdns/main.bicep' = if (empty(existingPrivateDnsZonesResourceGroupId)) {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'st-dns'), 64)
  params: {
    privateDnsZoneName: privateDnsZoneName
    virtualNetworkId: virtualNetworkId
    tags: tags
  }
}

// TODO: Add lock to storage account to avoid accidental deletion

output id string = storageAccount.outputs.id
output name string = storageAccount.outputs.name
output containerName string = storageAccount.outputs.containerName
