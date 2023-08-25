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

module appService 'webapp.bicep' = {
  name: 'DeployAppService'
  params:{
    webAppName: webAppName
    appServicePlan:appServicePlan
    location:location
    skuName: skuName
    skuTier: skuTier
    subnetId: subnetId
    linuxFxVersion:linuxFxVersion
    tags: tags
    dbHostName:dbHostName
    dbName:dbName
    dbPassword: dbPassword
    dbUserName: dbUserName
  }
}

output webAppIdentity string = appService.outputs.webAppIdentity

