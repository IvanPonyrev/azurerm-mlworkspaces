using module .\classes\Token.psm1
using module .\classes\Certificate.psm1

class Deployment {
    [string] $ResourceGroupName

    [object] $TemplateFile

    [object] $TemplateParametersFile

    [hashtable] $OptionalParameters

    [object] $StorageAccount

    [object] $Secrets

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
        $this.Secrets = @{
            secrets = @()
        }
        Get-AzureStorageContainer -Context $this.StorageAccount.Context | ForEach-Object {
            $container = $_.Name
            $this.Secrets.secrets += [Token]::new("$($container)LocationSasToken", $container, $this.StorageAccount.Context).GetToken()
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
                    "*LocationSasToken" {
                        $this.OptionalParameters[$_] = ConvertTo-SecureString -AsPlainText -Force `
                            ($this.Secrets.secrets | Where-Object name -eq $_).value
                    }
                    "secrets" {
                        $this.OptionalParameters[$_] = $this.Secrets
                    }
                    "vaultAdminId" {
                        $this.OptionalParameters[$_] = ConvertTo-SecureString -AsPlainText -Force `
                            (Get-AzureRmADUser | ? UserPrincipalName -match (Get-AzureRmContext).Account.Id.ToLower().Replace("@", "_") | select -First 1 Id).Id.ToString()
                    }
                }
            } else {
                switch ($_) {
                    "certificates" {
                        $certificates = @{
                            certificates = @()
                        }
                        $this.TemplateParametersFile.parameters.$_.value.certificates | ForEach-Object {
                            $certificate = [Certificate]::new($_.name)
                            $certificates.certificates += $certificate.GetCertificate()
                            $this.Secrets.secrets += $certificate.GetPassword()
                            $certificate.RemoveCertificate()
                        }
                        $this.OptionalParameters[$_] = $certificates
                        $this.OptionalParameters["secrets"] = $this.Secrets
                    }
                }
            }
        }

        return $this.OptionalParameters
    }
}