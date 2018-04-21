#Requires -Version 3.0

Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] $ResourceGroupName = 'storage',
    [switch] $UploadArtifacts,
    [string] $TemplateFile = '.\resources\storageAccounts.json',
    [string] $TemplateParametersFile = 'azuredeploy.parameters.json',
    [string] $ArtifactStagingDirectory = '.',
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
	New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
										-ResourceGroupName $ResourceGroupName `
										-TemplateFile $TemplateFile `
										-TemplateParameterFile $TemplateParametersFile `
										@OptionalParameters `
										-Force -Verbose `
										-ErrorVariable ErrorMessages
	if ($ErrorMessages) {
		Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
	}
}

if ($UploadArtifacts) {
    # Convert relative paths to absolute paths if needed
    $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))

    # Parse the parameter file and update the values of artifacts location and artifacts location SAS token if they are present
    $JsonParameters = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
    if (($JsonParameters | Get-Member -Type NoteProperty 'parameters') -ne $null) {
        $JsonParameters = $JsonParameters.parameters
    }

	$JsonParameters.storageAccounts.value | % {
		$StorageAccountName = $_.name

		# Create a storage account name if none was provided
		if ($StorageAccountName -eq '') {
			$StorageAccountName = 'stage' + ((Get-AzureRmContext).Subscription.SubscriptionId).Replace('-', '').substring(0, 19)
		}

		$StorageAccount = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -like "$StorageAccountName*" })

        Get-ChildItem "$ArtifactStagingDirectory" -Recurse -Directory | % {
    		$storageContainer = New-AzureStorageContainer -Name "$($_.BaseName)" -Context $StorageAccount.Context -ErrorAction SilentlyContinue
            
            Get-ChildItem '.\*.json' -Recurse -File | % {
                Set-AzureStorageBlobContent -File $_.FullName -Blob $_.Name -Container $storageContainer.Name 
            }
        }
		Get-ChildItem ($ArtifactStagingDirectory + "\$StorageContainerName\generalized\*.json") -Recurse -File | % {
			Set-AzureStorageBlobContent -File $_.FullName -Blob $_.Name -Container $StorageContainerName -Context $StorageAccount.Context -Force
		}
	}
}