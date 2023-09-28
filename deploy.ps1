# PowerShell script to deploy the main.bicep template with parameter values

#Requires -Modules "Az"
#Requires -PSEdition Core

# Use these parameters to customize the deployment instead of modifying the default parameter values
[CmdletBinding()]
Param(
    [Parameter(Position = 1)]
    [string]$Location,
    [Parameter(Position = 2)]
    [string]$TemplateParameterFile = "./main-sample.bicepparam",
    [Parameter(Position = 3)]
    [string]$SubscriptionId
)

# Define common parameters for the New-AzDeployment cmdlet
[hashtable]$CmdLetParameters = @{
    Location     = $Location
    TemplateFile = '.\main.bicep'
}

# Convert the .bicepparam file to JSON to read values that will be used to construct the deployment name
$JsonParamFile = [System.IO.Path]::ChangeExtension($TemplateParameterFile, 'json')
Write-Verbose $JsonParamFile
bicep build-params $TemplateParameterFile --outfile $JsonParamFile

<# HACK: 2023-09-14: At this time, .bicepparam cannot be combined with inline parameters,
which is needed to supply a new random database password. So we're using the JSON file here too. #>
$CmdLetParameters.Add('TemplateParameterFile', $JsonParamFile)

# Read the values from the parameters file, to use when generating the $DeploymentName value
$ParameterFileContents = (Get-Content $JsonParamFile | ConvertFrom-Json)
[string]$WorkloadName = $ParameterFileContents.parameters.workloadName.value
[string]$Environment = $ParameterFileContents.parameters.environment.value

# Generate a unique name for the deployment
[string]$DeploymentName = "$WorkloadName-$Environment-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)"
$CmdLetParameters.Add('Name', $DeploymentName)

# Determine if a cloud context switch is required
$AzContext = Get-AzContext

if ($SubscriptionId -ne $AzContext.Subscription.Id) {
    Write-Verbose "Current subscription: '$($AzContext.Subscription.Id)'. Switching subscription."
    Select-AzSubscription $SubscriptionId
}
else {
    Write-Verbose "Current Subscription: '$($AzContext.Subscription.Name)'. No switch needed."
}

# Import the Generate-Password module
Import-Module .\scripts\PowerShell\Generate-Password.psm1

# Generate a 25 character random password for the MySQL admin user
[securestring]$SqlPassword = New-RandomPassword 25

# Remove the Generate-Password module from the session
Remove-module Generate-Password

$CmdLetParameters.Add('sqlPassword', $SqlPassword)

# Execute the deployment
$DeploymentResult = New-AzDeployment @CmdLetParameters

# Evaluate the deployment results
if ($DeploymentResult.ProvisioningState -eq 'Succeeded') {
    Write-Host "🔥 Deployment succeeded."
}
else {
    $DeploymentResult
}