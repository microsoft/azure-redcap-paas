using './main.bicep'

// These parameters might have acceptable defaults.
param location = 'eastus'
param environment = 'demo'
param workloadName = 'redcap'
param namingConvention = '{workloadName}-{env}-{rtype}-{loc}-{seq}'
param sequence = 1

// These parameters should be modified for your environment
param identityObjectId = '<Valid Entra ID object ID for permissions assignment>'
param vnetAddressSpace = '10.0.0.0/24'

// If providing redcapZipUrl, you do not need to provide REDCap community username and password.
// redcapZipUrl should not require authentication.
param redcapZipUrl = '<Valid Redcap Zip URL>'
param redcapCommunityUsername = '<Valid Redcap Community Username>'
param redcapCommunityPassword = '<Valid Redcap Community Password>'

// ** Do not specify anything here! **
// This parameter is required to be here but should be blank so the password doesn't leak. 
// A password is generated for each deployment.
param sqlPassword = ''
param scmRepoUrl = '<Valid Scm Repo URL where build scripts are downloaded from>'
param scmRepoBranch = '<Valid Scm Repo Branch where build scripts are downloaded from>'
