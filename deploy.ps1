#Requires -Version 3.0

Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] $ResourceGroupName = 'storage',
	[array] $LinkedResourceGroups = @('network', 'machines', 'web', 'workspaces', 'sql', 'vaults'),
    [switch] $UploadArtifacts,
    [string] $TemplateFile = '.\resources\storageAccounts.json',
    [string] $TemplateParametersFile = '.\params\storageAccounts.parameters.json',
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

$userObjectId = 'userObjectId'
if ((Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json).parameters.PSObject.Properties.name -match $userObjectId) {
	$OptionalParameters[$userObjectId] = (Get-AzureRmADUser -UserPrincipalName (Get-AzureRmContext).Account).Id
}

Get-ChildItem -Directory | % { 
	$tokenName = "_$($_.Name)LocationSasToken"
	if ((Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json).parameters.PSObject.Properties.name -match "$tokenName") {
		if ($OptionalParameters[$tokenName] -eq $null) {
			$OptionalParameters[$tokenName] = ConvertTo-SecureString -AsPlainText -Force `
				(New-AzureStorageContainerSASToken -Container "$($_.Name)" -Context (Get-AzureRmStorageAccount -ResourceGroupName storage | ? StorageAccountName -like 'storage*').Context -Permission r -ExpiryTime (Get-Date).AddHours(4))
		}
	}
}

# Create or update the resource group using the specified template file and template parameters file
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force

$LinkedResourceGroups | % { 
	New-AzureRmResourceGroup -Name $_ -Location $ResourceGroupLocation -Verbose -Force
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
		$storageAccountName = $_.name

		Write-Verbose -Message "STORAGE ACCOUNT: $storageAccountName"
		# Create a storage account name if none was provided
		if ($storageAccountName -eq '') {
			$storageAccountName = 'stage' + ((Get-AzureRmContext).Subscription.SubscriptionId).Replace('-', '').substring(0, 19)
		}

		$storageAccount = Get-AzureRmStorageAccount | ?  StorageAccountName -like "$storageAccountName*" | select -First 1

        Get-ChildItem $ArtifactStagingDirectory -Recurse -Directory | % {
    		$storageContainer = New-AzureStorageContainer -Name "$($_.BaseName)" -Context $storageAccount.Context -ErrorAction SilentlyContinue

			if ($storageContainer -eq $null) {
				$storageContainer = Get-AzureStorageContainer -Name "$($_.BaseName)" -Context $storageAccount.Context
			}

            Get-ChildItem "$($_.FullName)\*.json" -File | % {
                Set-AzureStorageBlobContent -File "$($_.FullName)" -Blob $_.Name -Container $storageContainer.Name  -Context $storageAccount.Context -Force
            }
        }
	}
}