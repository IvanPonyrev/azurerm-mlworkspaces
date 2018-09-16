using module .\Pfx.psm1
class AdApplication {

    hidden [string] $Name
    
    hidden [string] $ApplicationId
    
    [Pfx] $Certificate

    AdApplication([string] $Name) {
        $this.Name = $Name
        $this.Certificate = [Pfx]::new("$($Name)Certificate")

        $this.ApplicationId = $this.SetApplication()
    }

    hidden [string] SetApplication() {
        $application = Get-AzureRmADApplication -DisplayName $this.Name
        if ($null -eq $application) {
            $application = New-AzureRmADApplication -DisplayName $this.Name `
                -IdentifierUris "https://localhost/$($this.Name)" `
                -HomePage "https://localhost/$($this.Name)"
        }
        return $application.ApplicationId
    }

    [string] GetApplicationId() {
        return $this.ApplicationId
    }

    <# .Description Creates a service principal for this AD application. #>
    [void] CreateServicePrincipal() {
        $servicePrincipal = Get-AzureRmADServicePrincipal -DisplayName $this.Name | select -First 1
        if ($null -ne $servicePrincipal) {
            Remove-AzureRmADServicePrincipal -Id $servicePrincipal.Id -Force
        }
        New-AzureRmADServicePrincipal -ApplicationId $this.ApplicationId `
            -CertValue $this.Certificate.GetCertificate().base64Value `
            -EndDate $this.Certificate.GetEndDate() `
            -StartDate ([System.DateTime]::Now)
        
        # Wait a moment for the service principal, then set role assignment.
        Get-AzureRmRoleAssignment | ? DisplayName -eq $null | Remove-AzureRmRoleAssignment
        Start-Sleep -Seconds 8
        New-AzureRmRoleAssignment -ApplicationId $this.ApplicationId `
            -RoleDefinitionName Contributor
    }
}