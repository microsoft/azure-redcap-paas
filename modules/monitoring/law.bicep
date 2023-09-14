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

  // identity: {
  //   type: 'string'
  //   userAssignedIdentities: {}
  // }
  properties: {
    // defaultDataCollectionRuleResourceId: 'string'
    // features: {
    //   clusterResourceId: 'string'
    //   disableLocalAuth: bool
    //   enableDataExport: bool
    //   enableLogAccessUsingOnlyResourcePermissions: bool
    //   immediatePurgeDataOn30Days: bool
    // }
    // forceCmkForQuery: bool
    // publicNetworkAccessForIngestion: 'string'
    // publicNetworkAccessForQuery: 'string'
    retentionInDays: retentionInDays
    sku: {
      // capacityReservationLevel: int
      name: logAnalyticsWorkspaceSku
    }
    // workspaceCapping: {
    //   dailyQuotaGb: int
    // }
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkSpace.id

