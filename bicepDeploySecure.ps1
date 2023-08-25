$startTime=Get-Date
Write-Host "Beginning deployment at $starttime"

Import-Module Azure -ErrorAction SilentlyContinue
$version = 0;

#DEPLOYMENT OPTIONS
#Please review the azuredeploy.bicep file for available options
$RGName        = "RG-Redcap"
$DeployRegion  = "eastus"

$parms = @{

    #Alternative to the zip file above, you can use REDCap Community credentials to download the zip file.
    "redcapCommunityUsername"     = "vishalkalal@thevktech.com";
    "redcapCommunityPassword"     = "abc@1234";
    "redcapAppZipVersion"         = "<REDCap version";

    #Mail settings
    "fromEmailAddress"            = "vishalkalal@thevktech.com";
    "smtpFQDN"                    = "smtp.thevktech.com"
    "smtpUser"                    = "smtpuser"
    "smtpPassword"                = "password@123"

    #Azure Web App
    "siteName"                    = "vkdemoredcap";
    "skuName"                     = "S1";
    "skuCapacity"                 = 1;

    #MySQL
    "administratorLogin"          = "vishalkalal";
    "administratorLoginPassword"  = "P@ssw0rd@123";

    # "databaseForMySqlCores"       = 2;
    # "databaseForMySqlFamily"      = "Gen5";
    # "databaseSkuSizeMB"           = 5120;
    # "databaseForMySqlTier"        = "GeneralPurpose";
    "mysqlVersion"                = "5.7";

    #Azure Storage
    "storageType"                 = "Standard_LRS";
    "storageContainerName"        = "redcap";

    #GitHub
    "repoURL"                     = "https://github.com/microsoft/azure-redcap-paas.git";
    "branch"                      = "master";

    #AVD session hosts
    "vmAdminUserName"             = "vishalkalal"
    "vmAdminPassword"             = "P@ssw0rd@123"

    #Domain join
    "domainJoinUsername"          = "ADDC01-admin"
    "domainJoinPassword"          = "Info$world"
    "adDomainFqdn"                = "thevktech.local"
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
$deployment = New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateParameterObject $parms -TemplateFile ".\azuredeploysecure.bicep" -Name "RedCAPDeploy$version"  -Force -Verbose

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
