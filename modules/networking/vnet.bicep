param location string = resourceGroup().location

@description('virtualNetworkName')
param virtualNetworkName string

@description('vnetAddressSpace')
param vnetAddressPrefix string

@description('subnetsDetails')
param subnets object

param tags object
param customDnsIPs array

var subnetDefsArray = items(subnets)

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [for (subnet, i) in subnetDefsArray: {
      name: subnet.key
      properties: {
        addressPrefix: subnet.value.addressPrefix
        serviceEndpoints: contains(subnet.value, 'serviceEndpoints') ? subnet.value.serviceEndpoints : null
        delegations: contains(subnet.value, 'delegation') && !empty(subnet.value.delegation) ? [
          {
            name: 'delegation'
            properties: {
              serviceName: subnet.value.delegation
            }
          }
        ] : null
      }
    }]

    dhcpOptions: {
      dnsServers: customDnsIPs
    }
  }
  tags: tags
}

output virtualNetworkId string = virtualNetwork.id

// Retrieve the subnets as an array of existing resources
// This is important because we need to ensure subnet return value is matched to the name of the subnet correctly - order matters
// This works because the parent property is set to the virtual network, which means this won't be attempted until the VNet is created
resource subnetRes 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' existing = [for subnet in subnetDefsArray: {
  name: subnet.key
  parent: virtualNetwork
}]

output subnets array = [for i in range(0, length((subnetDefsArray))): {
  '${subnetRes[i].name}': {
    id: subnetRes[i].id
    addressPrefix: subnetRes[i].properties.addressPrefix
    // routeTableId: contains(subnetRes[i].properties, 'routeTable') ? subnetRes[i].properties.routeTable.id : null
    // routeTableName: contains(subnetRes[i].properties, 'routeTable') ? routeTables[subnetRes[i].name].name : null
    // networkSecurityGroupId: contains(subnetRes[i].properties, 'networkSecurityGroup') ? subnetRes[i].properties.networkSecurityGroup.id : null
    // networkSecurityGroupName: contains(subnetRes[i].properties, 'networkSecurityGroup') ? networkSecurityGroups[subnetRes[i].name].name : null
    // Add as many additional subnet properties as needed downstream
  }
}]
