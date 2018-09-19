class Deployment {
    [string] $ResourceGroupName

    [object] $TemplateFile

    [object] $TemplateParametersFile

    [hashtable] $OptionalParameters

    [object] $StorageAccount

    [AdApplication] $AutomationApplication

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
        $this.AutomationApplication = [AdApplication]::new("automation")
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

            $extensions = @{ 
                $true = @("$($_.FullName)\*.json", "$($_.FullName)\*.ps1", "$($_.FullName)\*.psm1")
                $false = "$($_.FullName)\*.zip"
            }[ $_.BaseName -eq "modules" ]

            # Upload to blobs.
            Get-ChildItem $extensions -File | % {
                Set-AzureStorageBlobContent -File "$($_.FullName)" `
                    -Blob @{ $true = "$($_.Name)"; $false = "$($_.BaseName)" }[ $_.Extension -eq ".json" ] `
                    -Container $storageContainer.Name `
                    -Context $this.StorageAccount.Context -Force
            }
        }
    }

    <# .Description Creates a service principal and passes certificate and secret. #>
    hidden [void] SetServicePrincipal() {
        $this.AutomationApplication.CreateServicePrincipal()
        $this.Certificates.certificates += $this.AutomationApplication.Certificate.GetCertificate()
        $this.Secrets.secrets += $this.AutomationApplication.Certificate.GetPassword()
    }

    <# .Description Updates the automation certificate. #>
    [void] SetAutomationCertificate() {
        Set-AzureRmAutomationCertificate -AutomationAccountName automation `
            -ResourceGroupName $this.ResourceGroupName `
            -Name $this.AutomationApplication.Certificate.Name `
            -Path "$($this.AutomationApplication.Certificate.GetPath())\$($this.AutomationApplication.Certificate.Name).pfx" `
            -Password (ConvertTo-SecureString -AsPlainText -Force $this.AutomationApplication.Certificate.GetPassword().value)
    }

    <# .Description Generates tokens for each container in storage. #>
    hidden [void] GetSasTokens() {
        Get-AzureStorageContainer -Context $this.StorageAccount.Context | ForEach-Object {
            $container = $_.Name
            $this.Secrets.secrets += [Token]::new("$($container)LocationSasToken", $container, $this.StorageAccount.Context).GetToken()
        }
    }

    <# .Description Returns hashtable of optional parameters. #>
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
                        $this.OptionalParameters[$_] = $this.AutomationApplication.GetApplicationId()
                    }
                    "certificates" {
                        $this.OptionalParameters[$_] = $this.Certificates
                    }
                    "runbooksStartTime" {
                        $this.OptionalParameters[$_] = (Get-Date).ToUniversalTime().AddHours(1).ToString("MM/dd/yyyy HH:mm:ss")
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