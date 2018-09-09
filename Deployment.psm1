using module .\classes\Token.psm1
using module .\classes\Certificate.psm1

class Deployment {
    [string] $ResourceGroupName

    [object] $TemplateFile

    [object] $TemplateParametersFile

    [hashtable] $OptionalParameters

    [object] $StorageAccount

    [string] $ApplicationId

    [object] $Secrets = @{
        secrets = @()
    }

    [object] $Certificates = @{
        certificates = @()
    }

    Deployment([string] $ResourceGroupName, [string] $TemplateFile, [string] $TemplateParametersFile) {
        $this.ResourceGroupName = $ResourceGroupName
        $this.TemplateFile = Get-Content $TemplateFile -Raw | ConvertFrom-Json
        $this.TemplateParametersFile = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json

        $this.StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName | Select-Object -First 1
        $this.ApplicationId = $this.GetApplicationId("automation")
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
            $container = $_.Name
            $this.Secrets.secrets += [Token]::new("$($container)LocationSasToken", $container, $this.StorageAccount.Context).GetToken()
        }
    }

    hidden [guid] GetApplicationId([string] $applicationName) {
        $application = Get-AzureRmADApplication -DisplayName $applicationName
        if ($null -eq $application) {
            $application = New-AzureRmADApplication -DisplayName $applicationName `
                -IdentifierUris "https://localhost/$applicationName" `
                -HomePage "https://localhost/$applicationName"
        }

        $certificate = [Certificate]::new("$($applicationName)Certificate")
        $this.Certificates.certificates += $certificate.GetCertificate()

        $servicePrincipal = Get-AzureRmADServicePrincipal -DisplayName $applicationName | select -First 1
        if ($null -ne $servicePrincipal) {
            Remove-AzureRmADServicePrincipal -Id $servicePrincipal.Id -Force
        }
        
        # Create service principal, wait for completion, then create role assignment.
        Start-Job -Name ServicePrincipalCreation -ScriptBlock {
            New-AzureRmADServicePrincipal -ApplicationId $application.ApplicationId `
                -CertValue $certificate.GetCertificate().base64Value `
                -EndDate $certificate.GetEndDate() `
                -StartDate ([System.DateTime]::Now)
        }
        Wait-Job -Name ServicePrincipalCreation
        New-AzureRmRoleAssignment -ApplicationId $application.ApplicationId `
            -RoleDefinitionName Contributor

        $certificate.RemoveCertificate()

        return $application.ApplicationId
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
                    "applicationId" {
                        $this.OptionalParameters[$_] = $this.ApplicationId
                    }
                    "certificates" {
                        $this.OptionalParameters[$_] = $this.Certificates
                    }
                }
            } else {
                switch ($_) {
                    "certificates" {
                        $this.TemplateParametersFile.parameters.$_.value.certificates | ForEach-Object {
                            $certificate = [Certificate]::new($_.name)
                            $this.Certificates.certificates += $certificate.GetCertificate()
                            $certificate.RemoveCertificate()
                        }
                        $this.OptionalParameters[$_] = $this.Certificates
                    }
                }
            }
        }

        return $this.OptionalParameters
    }
}