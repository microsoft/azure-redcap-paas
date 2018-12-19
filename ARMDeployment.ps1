$startTime=Get-Date
Write-Host "Beginning deployment at $starttime"

Import-Module Azure -ErrorAction SilentlyContinue
$version = 0;

#DEPLOYMENT OPTIONS
#Please review the azuredeploy.json file for available options
$RGName        = "<YOUR RESOURCE GROUP>"
$DeployRegion  = "<SELECT AZURE REGION>"
$AssetLocation = "https://github.com/Microsoft/Azure-RedCAP-PaaS/blob/master/azuredeploy.json"

$parms = @{

    #Make your ZIP file temporarily accessible via a public file share
    "redCAPAppZip"                = "<path to your copy of the RedCAP distribution ZIP file>";

    #Azure Web App
    "siteName"                    = "<WEB SITE NAME, like 'redcap'>";
    "skuName"                     = "S1";

    #MySQL
    "administratorLogin"          = "<MySQL admin account name>";
    "administratorLoginPassword"  = "<MySQL admin login password>";

    "databaseSkuSizeMB"           = 5120;
    "databaseForMySqlTier"        = "GeneralPurpose";
    "databaseForMySqlFamily"      = "Gen5";
    "databaseForMySqlCores"       = 2;
    "mysqlVersion"                = "5.7";
    
    #Azure Storage
    "storageType"                 = "Standard_LRS";
    "storageContainerName"        = "redcap";

    #GitHub
    "repoURL"                     = "https://github.com/Microsoft/Azure-RedCAP-PaaS.git";
    "branch"                      = "master";
}
#END DEPLOYMENT OPTIONS

#Dot-sourced variable override (optional, comment out if not using)
$dotsourceSettings = "$($env:PSH_Settings_Files)redcap-azure.ps1"
if (Test-Path $dotsourceSettings) {
    . $dotsourceSettings
}

#ensure we're logged in
Get-AzureRmContext -ErrorAction Stop

#deploy
$TemplateFile = "$($AssetLocation)?x=$version"

try {
    Get-AzureRmResourceGroup -Name $RGName -ErrorAction Stop
    Write-Host "Resource group $RGName exists, updating deployment"
}
catch {
    $RG = New-AzureRmResourceGroup -Name $RGName -Location $DeployRegion
    Write-Host "Created new resource group $RGName."
}
$version ++
$deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $RGName -TemplateParameterObject $parms -TemplateFile $TemplateFile -Name "RedCAPDeploy$version"  -Force -Verbose

if ($deployment.ProvisioningState -eq "Succeeded") {
    $siteName = $deployment.Outputs.webSiteFQDN.Value
    start "https://$($siteName)/AzDeployStatus.php"
    Write-Host "---------"
    $deployment.Outputs | ConvertTo-Json

} else {
    $deperr = Get-AzureRmResourceGroupDeploymentOperation -DeploymentName "RedCAPDeploy$version" -ResourceGroupName $RGName
    $deperr | ConvertTo-Json
}

$endTime=Get-Date

Write-Host ""
Write-Host "Total Deployment time:"
New-TimeSpan -Start $startTime -End $endTime | Select Hours, Minutes, Seconds
