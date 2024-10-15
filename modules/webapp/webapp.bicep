param webAppName string
param appServicePlanName string
param location string
param skuName string
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
#disable-next-line secure-secrets-in-params
param redcapCommunityUsernameSecretRef string
#disable-next-line secure-secrets-in-params
param redcapCommunityPasswordSecretRef string
param scmRepoUrl string
param scmRepoBranch string
param prerequisiteCommand string

param appInsights_connectionString string
param appInsights_instrumentationKey string

param enablePrivateEndpoint bool

param smtpFQDN string = ''
param smtpPort string = ''
param smtpFromEmailAddress string = ''

// This is not a secret, it's a Key Vault reference
#disable-next-line secure-secrets-in-params
param storageAccountKeySecretRef string
param storageAccountName string
param storageAccountContainerName string
param minTlsVersion string = '1.2'

param uamiId string

resource appSrvcPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: skuName
    //tier: skuTier
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
      minTlsVersion: minTlsVersion
      ftpsState: 'FtpsOnly'
      appCommandLine: prerequisiteCommand
      appSettings: [
        // REDCap runtime settings
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
        // REDCap deployment settings
        {
          name: 'redcapAppZip'
          value: redcapZipUrl
        }
        {
          name: 'redcapCommunityUsername'
          value: redcapCommunityUsernameSecretRef
        }
        {
          name: 'redcapCommunityPassword'
          value: redcapCommunityPasswordSecretRef
        }
        {
          name: 'DBSslCa'
          value: DBSslCa
        }
        // SMTP, possibly legacy settings
        {
          name: 'smtpFQDN'
          value: smtpFQDN
        }
        {
          name: 'smtpPort'
          value: smtpPort
        }
        {
          name: 'fromEmailAddress'
          value: smtpFromEmailAddress
        }
        // END SMTP
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
        // EDOC configuration, used during deployment only
        {
          name: 'StorageKey'
          value: storageAccountKeySecretRef
        }
        {
          name: 'StorageAccount'
          value: storageAccountName
        }
        {
          name: 'StorageContainerName'
          value: storageAccountContainerName
        }
        // END EDOC
        {
          name: 'ENABLE_DYNAMIC_INSTALL'
          value: 'true'
        }
        {
          name: 'PRE_BUILD_COMMAND'
          value: 'apt-get update -qq && apt-get install default-mysql-client -yqq'
        }
        {
          // HACK: 2024-09-24: svaelter: Re-added to ensure /home/site/ini/redcap.ini and /home/site/ini/extensions.ini gets processed
          name: 'PHP_INI_SCAN_DIR'
          value: '/usr/local/etc/php/conf.d:/home/site/ini'
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

// SCM Basic Authentication is required when using the App Service Build Service
// Per https://learn.microsoft.com/en-us/azure/app-service/deploy-continuous-deployment?tabs=github%2Cappservice#what-are-the-build-providers
resource basicScmCredentials 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-01-01' = {
  parent: webApp
  name: 'scm'
  properties: {
    allow: true
  }
}

resource sourcecontrol 'Microsoft.Web/sites/sourcecontrols@2022-09-01' = {
  parent: webApp
  name: 'web'
  properties: {
    repoUrl: scmRepoUrl
    branch: scmRepoBranch
    isManualIntegration: true
  }
  dependsOn: [privateDnsZoneGroupsWebApp]
}

resource peWebApp 'Microsoft.Network/privateEndpoints@2022-07-01' = if (enablePrivateEndpoint) {
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

resource privateDnsZoneGroupsWebApp 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = if (enablePrivateEndpoint) {
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
