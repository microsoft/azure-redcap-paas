targetScope = 'subscription'

param resourceGroupName string
param location string
param tags object
param customTags object
param keyVaultName string
param peSubnetId string
param roleAssignments array = [{
  RoleDefinitionId:''
  objectId: ''
}]
param secrets array = [
  // {
  //   testSecret: 'testValue'
  // }
]
param privateDnsZoneName string
param virtualNetworkId string

var mergeTags = union(tags, customTags)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: mergeTags
}


module keyvault './kv.bicep' = {
  name: 'kvDeploy'
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
  name: 'deploy-peDns'
  scope: resourceGroup
  params:{
    privateDnsZoneName:privateDnsZoneName
    virtualNetworkId:virtualNetworkId
    tags: tags
  }
}

output keyVaultName string = keyvault.outputs.keyVaultName
