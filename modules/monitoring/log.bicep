param logAnalyticsWorkspaceName string
param location string
param tags object
param retentionInDays int = 30

@allowed([
  'PerGB2018'
])
param logAnalyticsWorkspaceSku string = 'PerGB2018'

resource logAnalyticsWorkSpace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    retentionInDays: retentionInDays
    sku: {
      name: logAnalyticsWorkspaceSku
    }
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkSpace.id

