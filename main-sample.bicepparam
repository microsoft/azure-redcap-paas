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

// There are two options for obtaining the REDCap zip file:
// 1. Specify a URL to a publicly accessible zip file.
//    This URL should not require authentication of any kind. For example, an Azure blob storage URL with a SAS token is supported.
// 2. Specify a REDCap community username and password to download the zip file from the REDCap community.
//    Do not specify a URL if you are using this option. The deployment script will download the zip file from the REDCap community.
param redcapZipUrl = '<Valid Redcap Zip URL>'
// -- OR --
param redcapCommunityUsername = '<Valid Redcap Community Username>'
param redcapCommunityPassword = '<Valid Redcap Community Password>'

// These values are used to configure the App Service Deployment Center.
// The defaults are the Microsoft-maintained Azure REDCap PaaS repository.
// However, you should consider forking that repository and referencing your fork.
param scmRepoUrl = 'https://github.com/Microsoft/azure-redcap-paas'
param scmRepoBranch = 'main'

// ** Do not specify anything here! **
// This parameter is required to ensure the parameter file is valid, but should be blank so the password doesn't leak. 
// A new password is generated for each deployment and stored in Key Vault.
param sqlPassword = ''
