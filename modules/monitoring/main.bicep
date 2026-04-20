param location string
param tags object
param customTags object
param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceSku string
param retentionInDays int
param appInsightsName string

param deploymentNameStructure string

var mergeTags = union(tags, customTags)

module logAnalyticsWorkspace 'law.bicep' = {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'log'), 64)
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    retentionInDays: retentionInDays
    location: location
    tags: mergeTags
  }
}

module appInsights 'appInsights.bicep' = {
  #disable-next-line BCP334
  name: take(replace(deploymentNameStructure, '{rtype}', 'appi'), 64)
  params: {
    appInsightsName: appInsightsName
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.logAnalyticsWorkspaceId
    location: location
    tags: mergeTags
  }
}

output appInsightsResourceId string = appInsights.outputs.appInsightsResourceId
output appInsightsInstrumentationKey string = appInsights.outputs.appInsightsInstrumentationKey
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.outputs.logAnalyticsWorkspaceId
