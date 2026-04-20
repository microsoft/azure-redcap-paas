param location string
param virtualNetworkName string
param vnetAddressPrefix string
param subnets object
param customDnsIPs array
param tags object
param customTags object

param deploymentNameStructure string

var mergeTags = union(tags, customTags)

module vNetModule 'vnet.bicep' = {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'vnet'), 64)
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
