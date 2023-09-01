using './azDeploySecureSub.bicep'

param location = 'eastus'
param environment = 'demo'
param workloadName = 'redcap'
param namingConvention = '{workloadName}-{env}-{rtype}-{loc}-{seq}'
param sequence = 1

param identityObjectId = '<Valid Entra ID object ID for permissions assignment>'
