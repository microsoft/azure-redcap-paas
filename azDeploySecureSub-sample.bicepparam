using './azDeploySecureSub.bicep'

param location = 'eastus'
param environment = 'demo'
param workloadName = 'redcap'
param namingConvention = '{workloadName}-{env}-{rtype}-{loc}-{seq}'
param sequence = 1

param identityObjectId = '<Valid Entra ID object ID for permissions assignment>'
param vnetAddressSpace = '10.230.0.0/24'
param redcapZipUrl ='<Valid Redcap Zip URL>'
param redcapCommunityUsername  = '<Valid Redcap Community Username>'
param redcapCommunityPassword = '<Valid Redcap Community Password>'
