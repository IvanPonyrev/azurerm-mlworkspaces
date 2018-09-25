workflow New-SqlFirewallRule {
    
    Param(
        [Parameter(Mandatory=$true)]
        [string] $ConnectionName,

        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string] $FirewallRuleName,

        [Parameter(Mandatory=$true)]
        [string] $StartIpAddress,

        [Parameter(Mandatory=$true)]
        [string] $EndIpAddress,

        [Parameter(Mandatory=$true)]
        [string] $SqlServerName
    )

    # Get connection and establish connection.
    $Connection = Get-AutomationConnection -Name $ConnectionName
    Add-AzureRmAccount -ServicePrincipal `
        -TenantId $Connection.TenantId `
        -ApplicationId $Connection.ApplicationId `
        -CertificateThumbprint $Connection.CertificateThumbprint

    # Get storage context and resources container token for read permission.
    $context = (Get-AzureRmStorageAccount -ResourceGroupName management | Select -First 1).Context
    $resourcesLocationSasToken = New-AzureStorageContainerSASToken -Context $Context `
            -Container resources `
            -Permission r `
            -ExpiryTime (Get-Date).AddMinutes(10) `
            -Verbose

    New-AzureRmResourceGroupDeployment -Name $FirewallRuleName `
        -ResourceGroupName $ResourceGroupName `
        -Mode Incremental `
        -TemplateUri "$($context.BlobEndPoint)resources/firewallRules.json$($resourcesLocationSasToken)" `
        -TemplateParameterObject @{
            ruleName = $FirewallRuleName
            startIpAddress = $StartIpAddress
            endIpAddress = $EndIpAddress
            sqlServerName = $SqlServerName
        }
}