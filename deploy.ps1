#Requires -Version 5.0
#Requires -Modules PKI
using module .\Deployment.psm1

Param(
    [string] [Parameter(Mandatory=$false)] $ResourceGroupLocation = 'eastus',
    [string] $ResourceGroupName = 'management',
	[array] $LinkedResourceGroups = @('network', 'web', 'workspaces', 'sql', 'cosmos'),
    [switch] $UploadArtifacts,
    [switch] $DeployStorage,
	[string] [ValidateSet("Complete", "Incremental")] $Mode = 'Incremental',
    [string] $TemplateFile = ".\azuredeploy.json",
    [string] $TemplateParametersFile = ".\azuredeploy.parameters.json",
    [switch] $ValidateOnly
)

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ','_'), '3.0.0')
} catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 5

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

# Create or update the resource group using the specified template file and template parameters file
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force
$LinkedResourceGroups | ForEach-Object {
	New-AzureRmResourceGroup -Name $_ -Location $ResourceGroupLocation -Verbose -Force
}

$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

# Deploy or update storage if flagged.
if ($DeployStorage) {
	New-AzureRmResourceGroupDeployment -Name "storageAccounts" -ResourceGroupName $ResourceGroupName -TemplateFile ".\resources\storageAccounts.json"
}

$Deployment = [Deployment]::new($ResourceGroupName, $TemplateFile, $TemplateParametersFile)
if ($UploadArtifacts) {
	$Deployment.UploadArtifacts()
}

$OptionalParameters = $Deployment.GetOptionalParameters()

if ($ValidateOnly) {
	$ErrorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
																					-TemplateFile $TemplateFile `
																					-TemplateParameterFile $TemplateParametersFile `
																					@OptionalParameters)
	if ($ErrorMessages) {
		Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'
	}
	else {
		Write-Output '', 'Template is valid.'
	}
}
else {
	New-AzureRmResourceGroupDeployment -Name (Get-ChildItem $TemplateFile).BaseName `
										-ResourceGroupName $ResourceGroupName `
										-Mode $Mode `
										-TemplateFile $TemplateFile `
										-TemplateParameterFile $TemplateParametersFile `
										@OptionalParameters `
										-Force -Verbose `
										-ErrorVariable ErrorMessages
	if ($ErrorMessages) {
		Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
	}
}