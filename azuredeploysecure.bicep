param location string = resourceGroup().location

var prefix = 'Redcap'
var myObjectId = 'd9608212-09d1-440a-a543-585ee85fcdf2'

var tags = {
  workload: prefix
}

var subnets = {
  PrivateLinkSubnet: {
    addressPrefix: '10.230.0.0/27'
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
    ]
  }
  ComputeSubnet: {
    addressPrefix: '10.230.0.32/27'
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Web'
        locations: [
          location
        ]
      }
    ]
  }
  IntegrationSubnet: {
    addressPrefix: '10.230.0.64/26'
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Web'
        locations: [
          location
        ]
      }
    ]
    delegation: 'Microsoft.Web/serverFarms'
  }
  MySQLFlexSubnet: {
    addressPrefix: '10.230.0.128/29'
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
    ]
    delegation: 'Microsoft.DBforMySQL/flexibleServers'
  }
}

module virtualNetwork './modules/networking/main.bicep' = {
  name: 'vnetDeploy'
  params: {

    virtualNetworkName: 'VNET-REDCAP'
    vnetAddressPrefix: '10.230.0.0/24'
    location: location
    subnets: subnets
    customDnsIPs: [
      //'192.160.0.4'
    ]
    privateDNSZones: [
      'privatelink.blob.core.windows.net'
      'privatelink.file.core.windows.net'
      'privatelink.mysql.database.azure.com'
      'privatelink.vaultcore.azure.net'
    ]
    tags: tags
  }
}

module storageAccounts './modules/storage/main.bicep' = {
  name: 'strgDeploy1'
  dependsOn: [ virtualNetwork ]
  params: {
    strgConfig: [
      {
        location: location
        storageAccountName: 'redcap${uniqueString(resourceGroup().id)}'
        peSubnetId: virtualNetwork.outputs.subnets.PrivateLinkSubnet.id
        storageContainerName: 'redcap'
        kind: 'StorageV2'
        storageAccountSku: 'Standard_LRS'
        //accessTier: 'Hot'
        privateDNSZones: [
          'privatelink.blob.core.windows.net'
        ]
        tags: tags
      }
      {
        location: location
        storageAccountName: 'fsrc${uniqueString(resourceGroup().id)}'
        peSubnetId: virtualNetwork.outputs.subnets.PrivateLinkSubnet.id
        storageContainerName: 'redcap'
        kind: 'FileStorage'
        storageAccountSku: 'Premium_LRS'
        //accessTier: 'Premium'
        privateDNSZones: [
          'privatelink.file.core.windows.net'
        ]
        tags: tags
      }
    ]
  }
}

var webAppName = 'webApp${uniqueString(resourceGroup().id)}'

module webApp './modules/webapp/main.bicep' = {
  name: 'webAppDeploy'
  params: {
    webAppName: webAppName
    appServicePlan: 'ASP-${webAppName}'
    location: location
    skuName: 'S1'
    skuTier: 'Standard'
    subnetId: virtualNetwork.outputs.subnets.IntegrationSubnet.id
    linuxFxVersion: 'php|7.4'
    tags: tags
    dbHostName: mysqlDbserver.outputs.dbServerName
    dbName: mysqlDbserver.outputs.dbName
    dbPassword: sqlPassword
    dbUserName: sqlUserName
  }
}

var avdPrefix = '${prefix}-AVD'
var customRdpProperty = 'audiocapturemode:i:1;camerastoredirect:s:*;audiomode:i:0;drivestoredirect:s:;redirectclipboard:i:1;redirectcomports:i:0;redirectprinters:i:1;redirectsmartcards:i:1;screen mode id:i:2;devicestoredirect:s:*'

module avd './modules/avd/avd.bicep' = {
  scope: resourceGroup()
  name: 'DeployAVD'
  params: {
    location: location
    // logworkspaceSub: logworkspaceSub
    // logworkspaceResourceGroup: logworkspaceResourceGroup
    // logworkspaceName: logworkspaceName
    hostPoolName: '${avdPrefix}-HP'
    hostPoolFriendlyName: '${avdPrefix} Host Pool'
    hostPoolType: 'Pooled'
    appGroupName: '${avdPrefix}-AG'
    appGroupFriendlyName: '${avdPrefix} AppGrp'
    loadBalancerType: 'DepthFirst'
    workspaceName: '${avdPrefix}-WS'
    customRdpProperty: customRdpProperty
    // tokenExpirationTime:
    maxSessionLimit: 5
    newBuild: true
    tags: tags
  }
}

var flexibleServerName = toLower(substring('${prefix}${uniqueString(resourceGroup().id)}', 0, 8))
var dbName = '${prefix}db'
var sqlPassword = 'P@ssw0rd' // this should be linked to keyvault secret.
var sqlUserName = '${flexibleServerName}admin'

module mysqlDbserver './modules/sql/sql.bicep' = {
  name: 'DeploymysqlDbserver'
  params: {
    flexibleServerName: toLower(flexibleServerName)
    location: location
    tags: tags
    skuName: 'Standard_B1s'
    SkuTier: 'Burstable'
    StorageSizeGB: 20
    StorageIops: 396
    subnetId: virtualNetwork.outputs.subnets.MySQLFlexSubnet.id
    privateDnsZone: 'privatelink.mysql.database.azure.com'
    adminUserName: '${flexibleServerName}admin'
    adminPassword: sqlPassword
    mysqlVersion: '8.0.21'
    dbName: dbName
  }
}

var keyVaultName = toLower(substring('${prefix}${uniqueString(resourceGroup().id)}', 0, 12))
module keyvault './modules/kv/kv.bicep' = {
  name: 'kvDeploy'
  params: {
    keyVaultName: keyVaultName
    location: location
    tags: tags
    objectIds: [
      webApp.outputs.webAppIdentity
      myObjectId
    ]
    subnetIds: [
      virtualNetwork.outputs.subnets.PrivateLinkSubnet.id
    ]
    privateDnsZone: 'privatelink.vaultcore.azure.net'
    secrets: [
      {
        name: 'sqlUserName'
        value: sqlUserName
      }
      {
        name: 'sqlPassword'
        value: sqlPassword
      }
    ]
  }
}

// // Azure Virtual Desktop and Session Hosts region

// resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-10-14-preview' = {
//   name: 'hp-${siteNameCleaned}'
//   location: location
//   identity: {
//     type: 'SystemAssigned'
//   }
//   managedBy: 'string'
//   properties: {
//     preferredAppGroupType: 'Desktop'
//     description: 'REDCap AVD host pool for remote app and remote desktop services'
//     friendlyName: 'REDCap Host Pool'
//     hostPoolType: 'Pooled'
//     loadBalancerType: 'BreadthFirst'
//     maxSessionLimit: 999999
//     registrationInfo: {
//       expirationTime: avdRegistrationExpiriationDate
//     }
//     validationEnvironment: false
//   }
// }

// resource applicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2022-10-14-preview' = {
//   name: 'dag-${siteNameCleaned}'
//   location: location
//   properties: {
//     applicationGroupType: 'Desktop'
//     description: 'Windpws 10 Desktops'
//     friendlyName: 'REDCap Workstation'
//     hostPoolArmPath: hostPool.id
//   }
// }

// resource avdWorkspace 'Microsoft.DesktopVirtualization/workspaces@2022-10-14-preview' = {
//   name: 'ws-${siteNameCleaned}'
//   location: location
//   properties: {
//     applicationGroupReferences: [
//       applicationGroup.id
//     ]
//     description: 'Session desktops'
//     friendlyName: 'REDCAP Workspace'
//   }
// }

// resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = [for i in range(0, AVDnumberOfInstances): {
//   name: 'nic-redcap-${i}'
//   location: location
//   properties: {
//     ipConfigurations: [
//       {
//         name: 'ipconfig'
//         properties: {
//           privateIPAllocationMethod: 'Dynamic'
//           subnet: {
//             id: redcapComputeSubnet.id
//           }
//         }
//       }
//     ]
//   }
// }]

// resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = [for i in range(0, AVDnumberOfInstances): {
//   name: 'vm-redcap-${i}'
//   location: location
//   properties: {
//     licenseType: 'Windows_Client'
//     hardwareProfile: {
//       vmSize: vmSku
//     }
//     osProfile: {
//       computerName: 'vm-redcap-${i}'
//       adminUsername: vmAdminUserName
//       adminPassword: vmAdminPassword
//       windowsConfiguration: {
//         enableAutomaticUpdates: false
//         patchSettings: {
//           patchMode: 'Manual'
//         }
//       }
//     }
//     storageProfile: {
//       osDisk: {
//         name: 'vm-OS-${i}'
//         caching: vmDiskCachingType
//         managedDisk: {
//           storageAccountType: vmDiskType
//         }
//         osType: 'Windows'
//         createOption: 'FromImage'
//       }
//       // TODO Turn into params
//       imageReference: {
//         publisher: 'microsoftwindowsdesktop'
//         offer: 'office-365'
//         sku: '20h2-evd-o365pp'
//         version: 'latest'
//       }
//       dataDisks: []
//     }
//     networkProfile: {
//       networkInterfaces: [
//         {
//           id: nic[i].id
//         }
//       ]
//     }
//   }
//   dependsOn: [
//     nic[i]
//   ]
// }]

// // Reference https://github.com/Azure/avdaccelerator/blob/e247ec5d1ba5fac0c6e9f822c4198c6b41cb77b4/workload/bicep/modules/avdSessionHosts/deploy.bicep#L162
// // Needed to get the hostpool in order to pass registration info token, else it comes as null when usiung
// // registrationInfoToken: hostPool.properties.registrationInfo.token
// // Workaround: reference https://github.com/Azure/bicep/issues/6105
// // registrationInfoToken: reference(getHostPool.id, '2021-01-14-preview').registrationInfo.token - also does not work
// resource getHostPool 'Microsoft.DesktopVirtualization/hostPools@2019-12-10-preview' existing = {
//   name: hostPool.name
// }

// // Deploy the AVD agents to each session host
// resource avdAgentDscExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for i in range(0, AVDnumberOfInstances): {
//   name: 'AvdAgentDSC'
//   parent: vm[i]
//   location: location
//   properties: {
//     publisher: 'Microsoft.Powershell'
//     type: 'DSC'
//     typeHandlerVersion: '2.73'
//     autoUpgradeMinorVersion: true
//     settings: {
//       modulesUrl: artifactsLocation
//       configurationFunction: 'Configuration.ps1\\AddSessionHost'
//       properties: {
//         hostPoolName: hostPool.name
//         registrationInfoToken: getHostPool.properties.registrationInfo.token
//         aadJoin: false
//       }
//     }
//   }
//   dependsOn: [
//     getHostPool
//   ]
// }]

// resource domainJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for i in range(0, AVDnumberOfInstances): {
//   name: 'DomainJoin'
//   parent: vm[i]
//   location: location
//   properties: {
//     publisher: 'Microsoft.Compute'
//     type: 'JsonADDomainExtension'
//     typeHandlerVersion: '1.3'
//     autoUpgradeMinorVersion: true
//     settings: {
//       name: adDomainFqdn
//       ouPath: adOuPath
//       user: domainJoinUsername
//       restart: 'true'
//       options: '3'
//     }
//     protectedSettings: {
//       password: domainJoinPassword
//     }
//   }
//   dependsOn: [
//     avdAgentDscExtension[i]
//   ]
// }]

// resource dependencyAgentExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for i in range(0, AVDnumberOfInstances): {
//   name: 'DAExtension'
//   parent: vm[i]
//   location: location
//   properties: {
//     publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
//     type: 'DependencyAgentWindows'
//     typeHandlerVersion: '9.5'
//     autoUpgradeMinorVersion: true
//   }
// }]

// resource antiMalwareExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for i in range(0, AVDnumberOfInstances): {
//   name: 'IaaSAntiMalware'
//   parent: vm[i]
//   location: location
//   properties: {
//     publisher: 'Microsoft.Azure.Security'
//     type: 'IaaSAntimalware'
//     typeHandlerVersion: '1.5'
//     autoUpgradeMinorVersion: true
//     settings: {
//       AntimalwareEnabled: true
//     }
//   }
// }]

// resource ansibleExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for i in range(0, AVDnumberOfInstances): {
//   name: 'AnsibleWinRM'
//   parent: vm[i]
//   location: location
//   properties: {
//     publisher: 'Microsoft.Compute'
//     type: 'CustomScriptExtension'
//     typeHandlerVersion: '1.10'
//     autoUpgradeMinorVersion: true
//     settings: {
//       fileUris: [ 'https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1' ]
//     }
//     protectedSettings: {
//       commandToExecute: 'powershell.exe -Command \'./ConfigureRemotingForAnsible.ps1; exit 0;\''
//     }
//   }
// }]

// output MySQLHostName string = '${uniqueServerName}.mysql.database.azure.com'
// output MySqlUserName string = '${administratorLogin}@${uniqueServerName}'
// output webSiteFQDN string = '${uniqueWebSiteName}.azurewebsites.net'
// output storageAccountName string = uniqueStorageName
// output storageContainerName string = storageContainerName
