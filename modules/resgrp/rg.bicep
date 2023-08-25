targetScope = 'subscription'

param rgName string
param location string
param tags object

resource resourcegroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: rgName
  location: location
  tags: tags
}

output regname string = resourcegroup.name
