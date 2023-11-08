param mySqlFlexServerName string
param principalId string
param roleDefinitionId string

resource server 'Microsoft.DBforMySQL/flexibleServers@2022-09-30-preview' existing = {
  name: mySqlFlexServerName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(server.id, principalId, roleDefinitionId)
  scope: server
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
  }
}
