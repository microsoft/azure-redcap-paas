param webAppName string
param appServicePlanName string
param location string
param skuName string
param skuTier string
param tags object
param linuxFxVersion string

param dbHostName string
param dbName string
#disable-next-line secure-secrets-in-params
param dbUserNameSecretRef string
#disable-next-line secure-secrets-in-params
param dbPasswordSecretRef string

param peSubnetId string
param privateDnsZoneId string
param integrationSubnetId string
@secure()
param redcapZipUrl string
@secure()
param redcapCommunityUsername string
@secure()
param redcapCommunityPassword string
param scmRepoUrl string
param scmRepoBranch string = 'main'
param preRequsitesCommand string

param appInsights_connectionString string
param appInsights_instrumentationKey string

#disable-next-line secure-secrets-in-params
param storageAccountKeySecretRef string
param storageAccountName string
param storageAccountContainerName string

param uamiId string

resource appSrvcPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

var DBSslCa = '/home/site/wwwroot/DigiCertGlobalRootCA.crt.pem'

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: webAppName
  location: location
  tags: tags
  properties: {
    httpsOnly: true
    serverFarmId: appSrvcPlan.id
    virtualNetworkSubnetId: integrationSubnetId
    keyVaultReferenceIdentity: uamiId
    siteConfig: {
      alwaysOn: true
      http20Enabled: true

      linuxFxVersion: linuxFxVersion
      minTlsVersion: '1.2'
      ftpsState: 'FtpsOnly'
      appCommandLine: preRequsitesCommand
      appSettings: [
        {
          name: 'redcapAppZip'
          value: redcapZipUrl
        }
        {
          name: 'DBHostName'
          value: dbHostName
        }
        {
          name: 'DBName'
          value: dbName
        }
        {
          name: 'DBUserName'
          value: dbUserNameSecretRef
        }
        {
          name: 'DBPassword'
          value: dbPasswordSecretRef
        }
        {
          name: 'redcapCommunityUsername'
          value: redcapCommunityUsername
        }
        {
          name: 'redcapCommunityPassword'
          value: redcapCommunityPassword
        }
        {
          name: 'DBSslCa'
          value: DBSslCa
        }
        {
          name: 'smtpFQDN'
          value: ''
        }
        {
          name: 'smtpPort'
          value: ''
        }
        {
          name: 'fromEmailAddress'
          value: ''
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights_instrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights_connectionString
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: '1'
        }
        {
          name: 'storageKey'
          value: storageAccountKeySecretRef
        }
        {
          name: 'storageAccount'
          value: storageAccountName
        }
        {
          name: 'storageContainerName'
          value: storageAccountContainerName
        }
      ]
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
}

resource webSiteName_web 'Microsoft.Web/sites/sourcecontrols@2022-09-01' = {
  parent: webApp
  name: 'web'
  properties: {
    repoUrl: scmRepoUrl
    branch: scmRepoBranch
    isManualIntegration: true
  }
}

resource peWebApp 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: 'pe-${webApp.name}'
  location: location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${webApp.name}'
        properties: {
          privateLinkServiceId: webApp.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroupsWebApp 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = {
  name: 'privatednszonegroup'
  parent: peWebApp
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'pe-${webAppName}'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

output webAppUrl string = webApp.properties.defaultHostName
