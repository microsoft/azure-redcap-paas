targetScope = 'subscription'
param resourceGroupName string
param location string

param webAppName string
param appServicePlanName string
param skuName string
param skuTier string
param linuxFxVersion string = 'php|8.2'
param dbHostName string
param dbUserName string
param tags object
param customTags object
param dbName string
param peSubnetId string
param privateDnsZoneName string
param virtualNetworkId string
param integrationSubnetId string

param appInsights_connectionString string
param appInsights_instrumentationKey string

@secure()
param redcapZipUrl string
@secure()
param redcapCommunityUsername string
@secure()
param redcapCommunityPassword string


@secure()
param dbPassword string

var mergeTags = union(tags, customTags)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: mergeTags
}

module appService 'webapp.bicep' = {
  name: 'DeployAppService'
  scope: resourceGroup
  params: {
    webAppName: webAppName
    appServicePlanName: appServicePlanName
    location: location
    skuName: skuName
    skuTier: skuTier
    linuxFxVersion: linuxFxVersion
    tags: mergeTags
    dbHostName: dbHostName
    dbName: dbName
    dbPassword: dbPassword
    dbUserName: dbUserName
    peSubnetId: peSubnetId
    privateDnsZoneId: privateDns.outputs.privateDnsId
    integrationSubnetId: integrationSubnetId

    appInsights_connectionString: appInsights_connectionString
    appInsights_instrumentationKey: appInsights_instrumentationKey

    redcapZipUrl: redcapZipUrl
    redcapCommunityUsername: redcapCommunityUsername
    redcapCommunityPassword: redcapCommunityPassword

  }
}

module privateDns '../pdns/main.bicep' = {
  name: 'deploy-peDns'
  scope: resourceGroup
  params: {
    privateDnsZoneName: privateDnsZoneName
    virtualNetworkId: virtualNetworkId
    tags: mergeTags
  }
}

output webAppIdentity string = appService.outputs.webAppIdentity

output webAppUrl string = appService.outputs.webAppUrl
