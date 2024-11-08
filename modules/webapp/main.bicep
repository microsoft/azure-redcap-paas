param location string = resourceGroup().location

param webAppName string
param appServicePlanName string
param skuName string
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

param smtpFQDN string = ''
param smtpPort string = ''
param smtpFromEmailAddress string = ''

#disable-next-line secure-secrets-in-params
param storageAccountKeySecretRef string
param storageAccountName string
param storageAccountContainerName string

param appInsights_connectionString string
param appInsights_instrumentationKey string

param enablePrivateEndpoint bool

param scmRepoUrl string
param scmRepoBranch string
@secure()
param redcapZipUrl string
#disable-next-line secure-secrets-in-params
param redcapCommunityUsernameSecretRef string
#disable-next-line secure-secrets-in-params
param redcapCommunityPasswordSecretRef string
param prerequisiteCommand string

param existingPrivateDnsZonesResourceGroupId string = ''

param timeZone string = 'UTC'

param uamiId string

// Disabling this check because this is not a secret; it's a reference to Key Vault
#disable-next-line secure-secrets-in-params
param dbPasswordSecretRef string

param deploymentNameStructure string

var mergeTags = union(tags, customTags)

module appService 'webapp.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'planAndApp'), 64)
  params: {
    webAppName: webAppName
    appServicePlanName: appServicePlanName
    location: location
    skuName: skuName
    linuxFxVersion: linuxFxVersion
    tags: mergeTags
    dbHostName: dbHostName
    dbName: dbName
    dbPasswordSecretRef: dbPasswordSecretRef
    dbUserNameSecretRef: dbUserNameSecretRef
    peSubnetId: peSubnetId
    privateDnsZoneId: empty(existingPrivateDnsZonesResourceGroupId)
      ? privateDns.outputs.privateDnsId
      : '${existingPrivateDnsZonesResourceGroupId}/providers/Microsoft.Network/privateDnsZones/${privateDnsZoneName}'
    integrationSubnetId: integrationSubnetId

    appInsights_connectionString: appInsights_connectionString
    appInsights_instrumentationKey: appInsights_instrumentationKey

    redcapZipUrl: redcapZipUrl
    redcapCommunityUsernameSecretRef: redcapCommunityUsernameSecretRef
    redcapCommunityPasswordSecretRef: redcapCommunityPasswordSecretRef

    scmRepoUrl: scmRepoUrl
    scmRepoBranch: scmRepoBranch
    prerequisiteCommand: prerequisiteCommand

    storageAccountContainerName: storageAccountContainerName
    storageAccountKeySecretRef: storageAccountKeySecretRef
    storageAccountName: storageAccountName

    smtpFQDN: smtpFQDN
    smtpFromEmailAddress: smtpFromEmailAddress
    smtpPort: smtpPort

    uamiId: uamiId

    enablePrivateEndpoint: enablePrivateEndpoint

    timeZone: timeZone
  }
}

module privateDns '../pdns/main.bicep' = if (empty(existingPrivateDnsZonesResourceGroupId)) {
  name: take(replace(deploymentNameStructure, '{rtype}', 'app-dns'), 64)
  params: {
    privateDnsZoneName: privateDnsZoneName
    virtualNetworkId: virtualNetworkId
    tags: mergeTags
  }
}

output webAppUrl string = appService.outputs.webAppUrl
