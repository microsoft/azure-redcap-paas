param keyVaultName string
param location string
param tags object
param enabledForDeployment bool = true
param enabledForDiskEncryption bool = false
param enabledForTemplateDeployment bool = true
param enableSoftDelete bool = true
param enableRbacAuthorization bool = true
param enablePurgeProtection bool = true
param subnetIds array
param objectIds array
param privateDnsZone string

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
      // virtualNetworkRules: [for subnetId in subnetIds: {
      //   id: subnetId
      // }]
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

var kvAdministratorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (objectId, i) in objectIds: {
  scope: keyVault
  name: guid(kvAdministratorRoleDefinitionId, objectId)
  properties: {
    roleDefinitionId: kvAdministratorRoleDefinitionId
    principalId: objectId
  }
}]

resource pekeyVault 'Microsoft.Network/privateEndpoints@2022-07-01' = [for (subnetId, i) in subnetIds: {
  name: 'pe-${keyVaultName}-${i}'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${keyVaultName}-${i}'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}]

resource pDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZone
}

resource privateDnsZoneGroupsKeyVault 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = [for (subnetId, i) in subnetIds: {
  name: 'privatednszonegroup'
  parent: pekeyVault[i]
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-keyvault'
        properties: {
          privateDnsZoneId: pDnsZone.id
        }
      }
    ]
  }
}]

// resource secretMySql 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
//   parent: keyVault
//   name: mySqlSecretName
//   properties: {
//     value: administratorLoginPassword
//   }
//   dependsOn: []
// }

// resource secretStorage 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
//   parent: keyVault
//   name: storageSecretName
//   properties: {
//     value: storageName.listKeys().keys[0].value
//   }
//   dependsOn: []
// }

// resource secretConnectionString 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
//   parent: keyVault
//   name: connectionStringSecretName
//   properties: {
//     value: 'Database=${databaseName};Data Source=${uniqueServerName}.mysql.database.azure.com;User Id=${administratorLogin}@mysql-${uniqueServerName};Password=${administratorLoginPassword}'
//   }
//   dependsOn: []
// }

// resource secretRCZip 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
//   parent: keyVault
//   name: redcaAppZipSecretName
//   properties: {
//     value: redcapAppZip
//   }
//   dependsOn: []
// }

// resource secretRCUser 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
//   parent: keyVault
//   name: redcapUsernameSecretName
//   properties: {
//     value: redcapCommunityUsername
//   }
//   dependsOn: []
// }

// resource secretRCPass 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
//   parent: keyVault
//   name: redcapPasswordSecretName
//   properties: {
//     value: redcapCommunityPassword
//   }
//   dependsOn: []
// }

// resource privateEndpointKeyVault 'Microsoft.Network/privateEndpoints@2022-07-01' = {
//   name: '${keyVaultName}-pe'
//   location: location
//   properties: {
//     subnet: {
//       id: redcapPrivateLinkSubnet.id
//     }
//     privateLinkServiceConnections: [
//       {
//         name: '${keyVaultName}-pe'
//         properties: {
//           privateLinkServiceId: keyVault.id
//           groupIds: [
//             'vault'
//           ]
//         }
//       }
//     ]
//   }
// }

// resource privateDnsZoneGroupsKeyVault 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = {
//   name: 'privatednszonegroupkeyvault'
//   parent: privateEndpointKeyVault
//   properties: {
//     privateDnsZoneConfigs: [
//       {
//         name: 'privatelink-keyvault'
//         properties: {
//           privateDnsZoneId: privateDnsZoneKeyVault.id
//         }
//       }
//     ]
//   }
// }
