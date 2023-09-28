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

param deploymentNameStructure string

param roleAssignments array = [ {
    RoleDefinitionId: ''
    objectId: ''
  } ]
param privateDnsZoneId string

//@secure()
param secrets array

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

module keyVaultSecretsModule 'kvSecrets.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'kv-secrets'), 64)
  params: {
    keyVaultName: keyVault.name
    secrets: secrets
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleAssignment in roleAssignments: {
  scope: keyVault
  name: guid(keyVault.id, roleAssignment.objectId, roleAssignment.RoleDefinitionId)
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
output id string = keyVault.id
