@description('privateDnsZone Name')
param privateDnsZoneName string

@description('virtualNetworkId')
param virtualNetworkId string

param tags object

var mergeTags = union(tags, {
    workloadType: 'privateDns'
  })

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  tags: mergeTags
}

resource privateDnsvnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'vnetlink'
  location: 'global'
  parent: privateDnsZone
  tags: mergeTags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

output privateDnsId string = privateDnsZone.id
