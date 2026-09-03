param location string
param virtualNetworkName string
param vnetAddressPrefix string
param subnets object
param customDnsIPs array
param tags object
param customTags object

param deploymentNameStructure string

param createNetworkSecurityGroup bool = false
param enableAvmTelemetry bool

var mergeTags = union(tags, customTags)

module networkSecurityGroupModule 'br/public:avm/res/network/network-security-group:0.5.3' = if (createNetworkSecurityGroup) {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'nsg'), 64)
  params: {
    name: replace(virtualNetworkName, 'vnet', 'nsg')
    location: location
    tags: mergeTags
    enableTelemetry: enableAvmTelemetry
  }
}
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
    networkSecurityGroupId: createNetworkSecurityGroup ? networkSecurityGroupModule.?outputs.resourceId! : null
  }
}

output virtualNetworkId string = vNetModule.outputs.virtualNetworkId
output subnets object = reduce(vNetModule.outputs.subnets, {}, (cur, next) => union(cur, next))
