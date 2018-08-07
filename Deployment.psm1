class Deployment {
    [string] $ResourceGroupName

    [string] $ScriptRoot

    [object] $StorageAccount

    [object[]] $SasTokens

    Deployment([string] $ResourceGroupName, [string] $ScriptRoot) {
        $this.ResourceGroupName = $ResourceGroupName
        $this.ScriptRoot = $ScriptRoot
        $this.StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName | Select-Object -First 1
    }

    [void] UploadArtifacts() {
        Get-ChildItem $this.ScriptRoot -Directory | ForEach-Object {
            # Create or get containers.
            $storageContainer = @{
                $true = New-AzureStorageContainer -Name $_.BaseName -Context $this.StorageAccount.Context -ErrorAction SilentlyContinue;
                $false = Get-AzureStorageContainer -Name $_.BaseName -Context $this.StorageAccount.Context;
            }[ $null -eq (Get-AzureStorageContainer -Name $_.BaseName -Context $this.StorageAccount.Context) ]

            # Upload to blobs.
            Get-ChildItem "$($_.FullName)\*.json" -File | % {
                Set-AzureStorageBlobContent -File "$($_.FullName)" -Blob $_.Name -Container $storageContainer.Name  -Context $this.StorageAccount.Context -Force
            }
        }
    }

    [object[]] GetSasTokens() {
        $this.SasTokens = @()
        Get-AzureStorageContainer -Context $this.StorageAccount.Context | ForEach-Object {
            $container = $_
            $this.SasTokens += @{
                name = "$($container.Name)LocationSasToken";
                value = ConvertTo-SecureString -AsPlainText -Force `
                    (New-AzureStorageContainerSASToken -Container $container.Name `
                        -Context $this.StorageAccount.Context `
                        -Permission r `
                        -ExpiryTime (Get-Date).AddHours(4) `
                        -Verbose);
            }
        }
        return $this.SasTokens
    }

    [securestring] GetToken($TokenName) {
        return ($this.SasTokens | ? name -eq $TokenName).value
    }
}