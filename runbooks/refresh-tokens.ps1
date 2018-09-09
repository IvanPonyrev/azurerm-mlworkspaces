workflow Refresh-Tokens {
    
    param(
        [Parameter(Mandatory=$true)]
        [string] $ConnectionName
    )

    $Connection = Get-AutomationConnection -Name $ConnectionName
    Connect-AzureRmAccount -ServicePrincipal `
        -TenantId $Connection.TenantId `
        -ApplicationId $Connection.ApplicationId `
        -CertificateThumbprint $Connection.CertificateThumbprint

    
}