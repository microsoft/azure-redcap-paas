@description('privateDnsZones Details')
param privateDNSZones array

@description('virtualNetworkName')
param virtualNetworkName string

@description('virtualNetworkId')
param virtualNetworkId string

resource privateDns 'Microsoft.Network/privateDnsZones@2020-06-01' = [for privateDnsZone in privateDNSZones: {
  name: privateDnsZone
  location: 'global'
}]

resource privateDnsvnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (privateDnsZone, i) in privateDNSZones: {
  name: 'vnetlink-${virtualNetworkName}'
  location: 'global'
  parent: privateDns[i]
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}]
