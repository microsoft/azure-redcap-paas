targetScope = 'subscription'

param resourceGroupName string
param location string
param virtualNetworkName string
param vnetAddressPrefix string
param subnets object
param customDnsIPs array
param tags object
param customTags object

param deploymentNameStructure string

var mergeTags = union(tags, customTags)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: mergeTags
}

module vNetModule 'vnet.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'vnet'), 64)
  scope: resourceGroup
  params: {
    virtualNetworkName: virtualNetworkName
    vnetAddressPrefix: vnetAddressPrefix
    location: location
    subnets: subnets
    tags: mergeTags
    customDnsIPs: customDnsIPs
  }
}

output virtualNetworkId string = vNetModule.outputs.virtualNetworkId
output subnets object = reduce(vNetModule.outputs.subnets, {}, (cur, next) => union(cur, next))
