param virtualNetworkName string
param vnetAddressPrefix string
param location string
param subnets object
param tags object
param privateDNSZones array
param customDnsIPs array

module vNetModule 'vnet.bicep' = {
  name: 'Deploy-${virtualNetworkName}'
  params: {
    location: location
    subnets: subnets
    virtualNetworkName: virtualNetworkName
    vnetAddressPrefix: vnetAddressPrefix
    tags: tags
    customDnsIPs: customDnsIPs
  }
}

module privateDNS 'privatedns.bicep' = {
  name: 'DeployPrivateDNS'
  dependsOn: [
    vNetModule
  ]
  params: {
    privateDNSZones: privateDNSZones
    virtualNetworkName: virtualNetworkName
    virtualNetworkId: vNetModule.outputs.virtualNetworkId
  }
}

output subnets object = reduce(vNetModule.outputs.subnets, {}, (cur, next) => union(cur, next))
