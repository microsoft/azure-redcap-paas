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

var mergeTags = union(tags, customTags)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: mergeTags
}

module storageBlob './storage.bicep' = {
  name: 'deploy-${storageAccountName}'
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

// TODO: Add lock to storage account to avoid accidental deletion

// TODO: Output storage account name, id
