# PowerShell script to deploy the main.bicep template with parameter values

#Requires -Modules "Az"
#Requires -PSEdition Core

# Use these parameters to customize the deployment instead of modifying the default parameter values
[CmdletBinding()]
Param(
    [ValidateSet('eastus2', 'eastus')]
    [Parameter()]
    [string]$Location = 'eastus',
    [Parameter(Position = 1)]
    [string]$TemplateParameterFile = "./azDeploySecureSub-sample.bicepparam",
    [Parameter(Position = 2)]
    [string]$SubscriptionId
)

# Define common parameters for the New-AzDeployment cmdlet
[hashtable]$CmdLetParameters = @{
    Location     = $Location
    # TODO: Rename to main.bicep?
    TemplateFile = '.\azDeploySecureSub.bicep'
}

$JsonParamFile = [System.IO.Path]::ChangeExtension($TemplateParameterFile, 'json')
Write-Verbose $JsonParamFile
bicep build-params $TemplateParameterFile --outfile $JsonParamFile

$CmdLetParameters.Add('TemplateParameterFile', $TemplateParameterFile)
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

# Execute the deployment
$DeploymentResult = New-AzDeployment @CmdLetParameters

# Evaluate the deployment results
if ($DeploymentResult.ProvisioningState -eq 'Succeeded') {
    Write-Host "🔥 Deployment succeeded."
}
else {
    $DeploymentResult
}