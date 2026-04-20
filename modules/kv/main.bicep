param location string
param tags object
param customTags object
param keyVaultName string
param peSubnetId string
param roleAssignments array = [
  {
    RoleDefinitionId: ''
    objectId: ''
  }
]
@secure()
param secrets object
param privateDnsZoneName string
param virtualNetworkId string

param existingPrivateDnsZonesResourceGroupId string = ''

param deploymentNameStructure string

var mergeTags = union(tags, customTags)

module keyVaultModule './kv.bicep' = {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'kv'), 64)
  params: {
    keyVaultName: keyVaultName
    location: location
    tags: mergeTags
    peSubnetId: peSubnetId
    privateDnsZoneId: empty(existingPrivateDnsZonesResourceGroupId)
      ? keyVaultPrivateDnsModule.?outputs.privateDnsId!
      : '${existingPrivateDnsZonesResourceGroupId}/providers/Microsoft.Network/privateDnsZones/${privateDnsZoneName}'
    secrets: secrets
    roleAssignments: roleAssignments
    deploymentNameStructure: deploymentNameStructure
  }
}

module keyVaultPrivateDnsModule '../pdns/main.bicep' = if (empty(existingPrivateDnsZonesResourceGroupId)) {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'kv-dns'), 64)
  params: {
    privateDnsZoneName: privateDnsZoneName
    virtualNetworkId: virtualNetworkId
    tags: tags
  }
}

output keyVaultName string = keyVaultModule.outputs.keyVaultName
output id string = keyVaultModule.outputs.id
