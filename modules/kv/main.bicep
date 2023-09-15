targetScope = 'subscription'

param resourceGroupName string
param location string
param tags object
param customTags object
param keyVaultName string
param peSubnetId string
param roleAssignments array = [ {
    RoleDefinitionId: ''
    objectId: ''
  } ]
param secrets array = []
param privateDnsZoneName string
param virtualNetworkId string

param deploymentNameStructure string

var mergeTags = union(tags, customTags)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: mergeTags
}

module keyvault './kv.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'kv'), 64)
  scope: resourceGroup
  params: {
    keyVaultName: keyVaultName
    location: location
    tags: tags
    peSubnetId: peSubnetId
    privateDnsZoneId: privateDns.outputs.privateDnsId
    secrets: secrets
    roleAssignments: roleAssignments
  }
}

module privateDns '../pdns/main.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'kv-dns'), 64)
  scope: resourceGroup
  params: {
    privateDnsZoneName: privateDnsZoneName
    virtualNetworkId: virtualNetworkId
    tags: tags
  }
}

output keyVaultName string = keyvault.outputs.keyVaultName
