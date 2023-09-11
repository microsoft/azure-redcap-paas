param keyVaultName string
param location string
param tags object
param enabledForDeployment bool = true
param enabledForDiskEncryption bool = false
param enabledForTemplateDeployment bool = true
param enableSoftDelete bool = true
param enableRbacAuthorization bool = true
param enablePurgeProtection bool = true
param peSubnetId string

param roleAssignments array = [ {
    RoleDefinitionId: ''
    objectId: ''
  } ]
param privateDnsZoneId string

param secrets array = [
  // {
  //   testSecret: 'testValue'
  // }
]

@allowed([
  'disabled'
  'enabled'

])
param publicNetworkAccess string = 'disabled'

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    createMode: 'default'
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enableSoftDelete: enableSoftDelete
    enableRbacAuthorization: enableRbacAuthorization
    enablePurgeProtection: enablePurgeProtection
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 7
    tenantId: subscription().tenantId
    publicNetworkAccess: publicNetworkAccess
  }
}

resource keyVaultSecrets 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = [for secret in secrets: {
  parent: keyVault
  name: secret.name
  properties: {
    value: secret.value
  }
}]

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleAssignment in roleAssignments: {
  scope: keyVault
  // TODO: Must include the object ID otherwise conflicts occur
  name: guid(roleAssignment.RoleDefinitionId, roleAssignment.objectId)
  properties: {
    roleDefinitionId: roleAssignment.RoleDefinitionId
    principalId: roleAssignment.objectId
  }
}]

resource pekeyVault 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: 'pe-${keyVaultName}'
  location: location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${keyVaultName}'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroupsKeyVault 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = {
  name: 'privatednszonegroup'
  parent: pekeyVault
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'pe-${keyVaultName}'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

output keyVaultName string = keyVault.name
