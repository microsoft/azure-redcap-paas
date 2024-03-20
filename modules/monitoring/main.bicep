targetScope = 'subscription'
param resourceGroupName string
param location string
param tags object
param customTags object
param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceSku string
param retentionInDays int
param appInsightsName string

param deploymentNameStructure string

var mergeTags = union(tags, customTags)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: mergeTags
}

module logAnalyticsWorkspace 'log.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'log'), 64)
  scope: resourceGroup
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceSku: logAnalyticsWorkspaceSku
    retentionInDays: retentionInDays
    location: location
    tags: mergeTags
  }
}

module appInsights 'appInsights.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'appi'), 64)
  scope: resourceGroup
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
