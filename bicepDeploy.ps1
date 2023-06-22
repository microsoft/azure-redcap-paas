$startTime=Get-Date
Write-Host "Beginning deployment at $starttime"

Import-Module Azure -ErrorAction SilentlyContinue
$version = 0;

#DEPLOYMENT OPTIONS
#Please review the azuredeploy.bicep file for available options
$RGName        = "<YOUR RESOURCE GROUP>"
$DeployRegion  = "<SELECT AZURE REGION>"

$parms = @{

    #Alternative to the zip file above, you can use REDCap Community credentials to download the zip file.
    "redcapCommunityUsername"     = "<REDCap Community site username>";
    "redcapCommunityPassword"     = "<REDCap Community site password>";
    "redcapAppZipVersion"         = "<REDCap version";

    #Mail settings
    "fromEmailAddress"            = "<email address listed as sender for outbound emails>";
    "smtpFQDN"                    = "<what it says>"
    "smtpUser"                    = "<login name for smtp auth>"
    "smtpPassword"                = "<password for smtp auth>"

    #Azure Web App
    "siteName"                    = "<WEB SITE NAME, like 'redcap'>";
    "skuName"                     = "S1";
    "skuCapacity"                 = 1;

    #MySQL
    "administratorLogin"          = "<MySQL admin account name>";
    "administratorLoginPassword"  = "<MySQL admin login password>";

    # "databaseForMySqlCores"       = 2;
    # "databaseForMySqlFamily"      = "Gen5";
    # "databaseSkuSizeMB"           = 5120;
    # "databaseForMySqlTier"        = "GeneralPurpose";
    "mysqlVersion"                = "5.7";
    
    #Azure Storage
    "storageType"                 = "Standard_LRS";
    "storageContainerName"        = "redcap";

    #GitHub
    "repoURL"                     = "https://github.com/vanderbilt-redcap/redcap-azure.git";
    "branch"                      = "master";

    #AVD session hosts
    "vmAdminUserName"             = "<vm admin user name>"
    "vmAdminPassword"             = "<vm admin password>"

    #Domain join
    "domainJoinUsername"          = "<domain join user name>"
    "domainJoinPassword"          = "<domain join password>"
    "adDomainFqdn"                = "<AD Domain FQDN>"


}
#END DEPLOYMENT OPTIONS

#ensure we're logged in
Get-AzContext -ErrorAction Stop

try {
    Get-AzResourceGroup -Name $RGName -ErrorAction Stop
    Write-Host "Resource group $RGName exists, updating deployment"
}
catch {
    $RG = New-AzResourceGroup -Name $RGName -Location $DeployRegion
    Write-Host "Created new resource group $RGName."
}
$version ++
$deployment = New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateParameterObject $parms -TemplateFile ".\azuredeploy.bicep" -Name "RedCAPDeploy$version"  -Force -Verbose

if ($deployment.ProvisioningState -eq "Succeeded") {
    $siteName = $deployment.Outputs.webSiteFQDN.Value
    start "https://$($siteName)/AzDeployStatus.php"
    Write-Host "---------"
    $deployment.Outputs | ConvertTo-Json

} else {
    $deperr = Get-AzResourceGroupDeploymentOperation -DeploymentName "RedCAPDeploy$version" -ResourceGroupName $RGName
    $deperr | ConvertTo-Json
}

$endTime=Get-Date

Write-Host ""
Write-Host "Total Deployment time:"
New-TimeSpan -Start $startTime -End $endTime | Select Hours, Minutes, Seconds
