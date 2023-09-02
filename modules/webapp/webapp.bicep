param webAppName string
// TODO: Rename to add Name
param appServicePlan string
param location string
param skuName string
param skuTier string
param tags object
param linuxFxVersion string = 'php|7.4'
param dbHostName string
param dbName string

@secure()
param dbUserName string

@secure()
param dbPassword string
//param repoUrl string

//param logAnalyticsWorkspaceId string = ''
param peSubnetId string
param privateDnsZoneId string

resource appSrvcPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlan
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
var redcapUrl = 'https://nam06.safelinks.protection.outlook.com/?url=https%3A%2F%2Fwww.dropbox.com%2Fscl%2Ffi%2F4qag6pi0b2qstv67jzrbw%2Fredcap13.8.5.zip%3Frlkey%3Dhb0qjhqwnmhj9vvcc9akqhcpp%26dl%3D1&data=05%7C01%7Cvishalkalal%40microsoft.com%7Cb471a7309e7f484bde2508db9cd7079a%7C72f988bf86f141af91ab2d7cd011db47%7C1%7C0%7C638276222972219379%7CUnknown%7CTWFpbGZsb3d8eyJWIjoiMC4wLjAwMDAiLCJQIjoiV2luMzIiLCJBTiI6Ik1haWwiLCJXVCI6Mn0%3D%7C3000%7C%7C%7C&sdata=eqvY%2BTynSLyiiGdxAYTz5fMqJJrK6aNfg0SFbnbT4oU%3D&reserved=0'

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: webAppName
  location: location
  tags: tags
  properties: {
    httpsOnly: true
    serverFarmId: appSrvcPlan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      minTlsVersion: '1.2'
      ftpsState: 'FtpsOnly'
      appSettings: [
        {
          name: 'redcapAppZip'
          value: redcapUrl
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
          value: dbUserName
        }
        {
          name: 'DBPassword'
          value: dbPassword
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
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// TODO: App Insights does not appear linked to web app
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  // TODO: Get name from name generator module
  name: 'appInsights-${webAppName}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    // TODO: This deploys Classic App Insights; must use Workspace-based now
    //WorkspaceResourceId: logAnalyticsWorkspaceId
    Flow_Type: 'Bluefield'
  }
}

resource peWebApp 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  // TODO: Inconsistent
  name: 'pe-webAppName'
  location: location
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${webAppName}'
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

output webAppIdentity string = webApp.identity.principalId
