#Requires -Version 3.0

Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] $ResourceGroupName = 'storage',
	[array] $LinkedResourceGroups = @('network', 'machines', 'web', 'workspaces', 'sql', 'vaults'),
    [switch] $UploadArtifacts,
	[string] [ValidateSet("Complete", "Incremental")] $Mode = 'Complete',
    [string] $TemplateFile,
    [string] $TemplateParametersFile,
    [switch] $ValidateOnly
)

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ','_'), '3.0.0')
} catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

# Create or update the resource group using the specified template file and template parameters file
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force

$LinkedResourceGroups | % { 
	New-AzureRmResourceGroup -Name $_ -Location $ResourceGroupLocation -Verbose -Force
}

# $params = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json

# $tokens = "_*LocationSasToken"
# if ($params.parameters.PSObject.Properties.name -match $tokens) {
# 	$storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName | Select -First 1

# 	$params.parameters.PSObject.Properties.name -match $tokens | % {
# 		$OptionalParameters[$_] = if ($OptionalParameters[$_] -eq $null) {
# 			ConvertTo-SecureString -AsPlainText -Force `
# 				(New-AzureStorageContainerSASToken -Container "$([regex]::Matches($_, '(?<=_).+?(?=Location)').value)" `
# 					-Context $storageAccount.Context `
# 					-Permission r `
# 					-ExpiryTime (Get-Date).AddHours(4) `
# 					-Verbose);
# 			}
# 	}
# }

if ($UploadArtifacts) {
    # Parse the parameter file and update the values of artifacts location and artifacts location SAS token if they are present
    $JsonParameters = Get-Content $TemplateFile -Raw | ConvertFrom-Json | Select-Object parameters

	$storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName | Select-Object -First 1
	if ($null -eq $storageAccount) {
		$storageAccount = (New-AzureRmResourceGroupDeployment -Name "storage" -ResourceGroupName $ResourceGroupName -TemplateFile ".\resources\storageAccounts.json").Outputs.storageAccount.value
	}

	Get-ChildItem -Directory | % {
		# Create or get containers.
		$storageContainer = @{
			$true = New-AzureStorageContainer -Name $_.BaseName -Context $storageAccount.Context -ErrorAction SilentlyContinue;
			$false = Get-AzureStorageContainer -Name $_.BaseName -Context $storageAccount.Context;
		}[ (Get-AzureStorageContainer -Name $_.BaseName -Context $storageAccount.Context) -eq $null ]

		# Upload to blobs.
		Get-ChildItem "$($_.FullName)\*.json" -File | % {
			Set-AzureStorageBlobContent -File "$($_.FullName)" -Blob $_.Name -Container $storageContainer.Name  -Context $storageAccount.Context -Force
		}
	}
}

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
	#((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
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