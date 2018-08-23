using module .\Certificate.psm1

class Deployment {
    [string] $ResourceGroupName

    [object] $TemplateFile

    [object] $TemplateParametersFile

    [hashtable] $OptionalParameters

    [object] $StorageAccount

    hidden [object[]] $SasTokens = @()

    Deployment([string] $ResourceGroupName, [string] $TemplateFile, [string] $TemplateParametersFile) {
        $this.ResourceGroupName = $ResourceGroupName
        $this.TemplateFile = Get-Content $TemplateFile -Raw | ConvertFrom-Json
        $this.TemplateParametersFile = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json

        $this.StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName | Select-Object -First 1
        $this.OptionalParameters = New-Object -TypeName Hashtable
    }

    <#
    .Description Uploads all artifacts in child directories of PSScriptRoot.
    #>
    [void] UploadArtifacts() {
        Get-ChildItem $PSScriptRoot -Directory | ForEach-Object {
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

    <#
    .Description Generates tokens for each container in storage.
    #>
    hidden [void] GetSasTokens() {
        Get-AzureStorageContainer -Context $this.StorageAccount.Context | ForEach-Object {
            $this.SasTokens += @{
                key = "_$($_.Name)LocationSasToken";
                value = ConvertTo-SecureString -AsPlainText -Force `
                    (New-AzureStorageContainerSASToken -Container "$($_.Name)" `
                        -Context $this.StorageAccount.Context `
                        -Permission r `
                        -ExpiryTime (Get-Date).AddHours(4) `
                        -Verbose);
            }
        }
    }

    <#
    .Description Returns hashtable of optional parameters.
    #>
    [hashtable] GetOptionalParameters() {
        $this.GetSasTokens()
        $this.TemplateFile.parameters.PSObject.Properties.Name | ForEach-Object {
            if ($this.TemplateParametersFile.parameters.PSObject.Properties.Name -notcontains $_) {
                switch -Wildcard ($_) {
                    "_*LocationSasToken" {
                        $this.OptionalParameters[$_] = ($this.SasTokens | ? key -eq $_).value
                    }
                }
            } else {
                switch ($_) {
                    "certificates" {
                        $certificates = @{
                            certificates = @()
                        }
                        $secrets = @{
                            secrets = @()
                        }
                        $this.TemplateParametersFile.parameters.$_.value.certificates | ForEach-Object {
                            $certificate = [Certificate]::new($_.name)
                            $certificates.certificates += $certificate.GetCertificate()
                            $secrets.secrets += $certificate.GetPassword()
                            $certificate.RemoveCertificate()
                        }
                        $this.OptionalParameters[$_] = $certificates
                        $this.OptionalParameters["secrets"] = $secrets
                    }
                }
            }
        }

        return $this.OptionalParameters
    }
}