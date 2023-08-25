// param location string = resourceGroup().location
// param storageAccountName string
// param storageContainerName string = ''
// param peSubnetId string
// param storageAccountSku string
// param kind string
// param accessTier string
// param privateDNSZones array
// param tags object

param strgConfig array = [
  // {
  //   location: string
  //   storageAccountName: storageAccountName
  //   peSubnetId: peSubnetId
  //   storageContainerName: storageContainerName
  //   kind: kind
  //   storageAccountSku: storageAccountSku
  //   accessTier: accessTier
  //   privateDNSZones: privateDNSZones
  //   tags: tags
  // }
]

module storageBlob './storage.bicep' = [for storage in strgConfig: {
  name: storage.storageAccountName
  params: {
    location: storage.location
    storageAccountName: storage.storageAccountName
    peSubnetId: storage.peSubnetId
    storageContainerName: storage.storageContainerName
    kind: storage.kind
    storageAccountSku: storage.storageAccountSku
    //accessTier: storage.accessTier
    privateDNSZones: storage.privateDNSZones
    tags: storage.tags
  }
}]
