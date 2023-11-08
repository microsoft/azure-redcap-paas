param location string

// @allowed([
//   'eastus'
//   'westus'
//   'westeurope'
//   'northeurope'
//   'uksouth'
// ])
// param workspaceLocation string

@description('If true Host Pool, App Group and Workspace will be created. Default is to join Session Hosts to existing AVD environment')
param newBuild bool = false

// @description('Expiration time for the HostPool registration token. This must be up to 30 days from todays date.')
// param tokenExpirationTime string

@allowed([
  'Personal'
  'Pooled'
])
param hostPoolType string = 'Pooled'
param hostPoolName string

// @allowed([
//   'Automatic'
//   'Direct'
// ])
// param personalDesktopAssignmentType string = 'Direct'
param maxSessionLimit int = 5

@allowed([
  'BreadthFirst'
  'DepthFirst'
  'Persistent'
])
param loadBalancerType string = 'BreadthFirst'

@description('Custom RDP properties to be applied to the AVD Host Pool.')
param customRdpProperty string

@description('Friendly Name of the Host Pool, this is visible via the AVD client')
param hostPoolFriendlyName string

@description('Name of the AVD Workspace to used for this deployment')
param workspaceName string = 'AVD-PROD'
param appGroupFriendlyName string
param tags object
param appGroupName string

// @description('Log Analytics workspace ID to join AVD to.')
// param logworkspaceID string
// param logworkspaceSub string
// param logworkspaceResourceGroup string
// param logworkspaceName string

// @description('List of application group resource IDs to be added to Workspace. MUST add existing ones!')
// param applicationGroupReferences string

// var appGroupResourceID = array(resourceId('Microsoft.DesktopVirtualization/applicationgroups/', appGroupName))
// var applicationGroupReferencesArr = applicationGroupReferences == '' ? appGroupResourceID : concat(split(applicationGroupReferences, ','), appGroupResourceID)

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-10-14-preview' = if (newBuild) {
  name: hostPoolName
  location: location
  properties: {
    friendlyName: hostPoolFriendlyName
    hostPoolType: hostPoolType
    loadBalancerType: loadBalancerType
    customRdpProperty: customRdpProperty
    preferredAppGroupType: 'Desktop'
    maxSessionLimit: maxSessionLimit
    validationEnvironment: false
    registrationInfo: {
      expirationTime: null
      token: null
      registrationTokenOperation: 'none'
    }
  }
  tags: tags
}

resource applicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2019-12-10-preview' = if (newBuild) {
  name: appGroupName
  location: location
  properties: {
    friendlyName: appGroupFriendlyName
    applicationGroupType: 'Desktop'
    description: 'Deskop Application Group created through Abri Deploy process.'
    hostPoolArmPath: resourceId('Microsoft.DesktopVirtualization/hostpools', hostPoolName)
  }
  dependsOn: [
    hostPool
  ]
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2019-12-10-preview' = if (newBuild) {
  name: workspaceName
  location: location
  properties: {
    applicationGroupReferences: [ applicationGroup.id ]
  }
}

// module Monitoring './Monitoring.bicep' = if (newBuild) {
//   name: 'Monitoring'
//   params: {
//     hostpoolName: hostPoolName
//     workspaceName: workspaceName
//     appgroupName: appGroupName
//     logworkspaceSub: logworkspaceSub
//     logworkspaceResourceGroup: logworkspaceResourceGroup
//     logworkspaceName: logworkspaceName
//   }
//   dependsOn: [
//     workspace
//     hostPool
//   ]
// }

output appGroupName string = appGroupName
