targetScope = 'subscription'
param resourceGroupName string
param location string

param webAppName string
param appServicePlanName string
param skuName string
param skuTier string
param linuxFxVersion string = 'php|8.2'
param dbHostName string
#disable-next-line secure-secrets-in-params
param dbUserNameSecretRef string
param tags object
param customTags object
param dbName string
param peSubnetId string
param privateDnsZoneName string
param virtualNetworkId string
param integrationSubnetId string

param appInsights_connectionString string
param appInsights_instrumentationKey string

param scmRepoUrl string
param scmRepoBranch string
@secure()
param redcapZipUrl string
@secure()
param redcapCommunityUsername string
@secure()
param redcapCommunityPassword string
param preRequsitesCommand string

// Disabling this check because this is no longer a secret; it's a reference to Key Vault
#disable-next-line secure-secrets-in-params
param dbPasswordSecretRef string

param deploymentNameStructure string

var mergeTags = union(tags, customTags)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: mergeTags
}

module appService 'webapp.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'planAndApp'), 64)
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
    dbPasswordSecretRef: dbPasswordSecretRef
    dbUserNameSecretRef: dbUserNameSecretRef
    peSubnetId: peSubnetId
    privateDnsZoneId: privateDns.outputs.privateDnsId
    integrationSubnetId: integrationSubnetId

    appInsights_connectionString: appInsights_connectionString
    appInsights_instrumentationKey: appInsights_instrumentationKey

    redcapZipUrl: redcapZipUrl
    redcapCommunityUsername: redcapCommunityUsername
    redcapCommunityPassword: redcapCommunityPassword

    scmRepoUrl: scmRepoUrl
    scmRepoBranch: scmRepoBranch
    preRequsitesCommand: preRequsitesCommand
  }
}

module privateDns '../pdns/main.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'app-dns'), 64)
  scope: resourceGroup
  params: {
    privateDnsZoneName: privateDnsZoneName
    virtualNetworkId: virtualNetworkId
    tags: mergeTags
  }
}

output webAppIdentity string = appService.outputs.webAppIdentity

output webAppUrl string = appService.outputs.webAppUrl
