using module .\Pfx.psm1
class AdApplication {

    hidden [string] $Name
    
    hidden [string] $ApplicationId
    
    [Pfx] $Certificate

    AdApplication([string] $Name) {
        $this.Name = Name
        $this.Certificate = [Pfx]::new("$($Name)Certificate")

        $this.GetApplication()
    }

    [string] GetApplication() {
        $this.ApplicationId = (Get-AzureRmADApplication -DisplayName $this.Name).ApplicationId
        if ($null -eq $this.ApplicationId) {
            $this.ApplicationId = (New-AzureRmADApplication -DisplayName $this.Name `
                -IdentifierUris "https://localhost/$($this.Name)" `
                -HomePage "https://localhost/$($this.Name)").ApplicationId
        }
        $this.CreateServicePrincipal()
        return $this.ApplicationId
    }

    <# .Description Creates a service principal for this AD application. #>
    [void] CreateServicePrincipal() {
        Remove-AzureRmADServicePrincipal -DisplayName $this.Name -Force -ErrorAction SilentlyContinue
        New-AzureRmADServicePrincipal -ApplicationId $this.ApplicationId `
            -CertValue $this.Certificate.GetCertificate().base64Value `
            -EndDate $this.Certificate.GetEndDate() `
            -StartDate ([System.DateTime]::Now)
        
        # Wait a moment for the service principal, then set role assignment.
        Start-Sleep -Seconds 5
        New-AzureRmRoleAssignment -ApplicationId $this.ApplicationId `
            -RoleDefinitionName Contributor
    }
}