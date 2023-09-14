param appInsightsName string
param location string
param tags object
param logAnalyticsWorkspaceId string

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    WorkspaceResourceId: logAnalyticsWorkspaceId
  }
}

output appInsightsResourceId string = appInsights.id
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
