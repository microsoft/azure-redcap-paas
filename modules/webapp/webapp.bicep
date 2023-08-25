param webAppName string
param appServicePlan string
param location string
param skuName string
param skuTier string
param tags object
param linuxFxVersion string = 'php|7.4'
param subnetId string
param dbHostName string
param dbName string
param dbUserName string

@secure()
param dbPassword string
//param repoUrl string

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
    virtualNetworkSubnetId: subnetId
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
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// resource webAppSourceControl 'Microsoft.Web/sourcecontrols@2022-03-01' = if(contains(repoUrl,'http')) {
//   name: 'web'
//   kind: 'string'
//   properties: {
//     expirationTime: 'string'
//     refreshToken: 'string'
//     token: 'string'
//     tokenSecret: 'string'
//   }
// }

output webAppIdentity string = webApp.identity.principalId
