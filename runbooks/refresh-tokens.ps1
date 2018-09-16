workflow Refresh-Tokens {
    
    Param(
        [Parameter(Mandatory=$true)]
        [string] $ConnectionName,

        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string] $VaultDeploymentName
    )

    # Get connection and establish connection.
    $Connection = Get-AutomationConnection -Name $ConnectionName
    Add-AzureRmAccount -ServicePrincipal `
        -TenantId $Connection.TenantId `
        -ApplicationId $Connection.ApplicationId `
        -CertificateThumbprint $Connection.CertificateThumbprint

    # Get storage context and resources container token for read permission.
    $context = (Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName | Select -First 1).Context
    $vault = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $VaultDeploymentName).Outputs.name.value
    $resourcesLocationSasToken = New-AzureStorageContainerSASToken -Context $Context `
            -Container resources `
            -Permission r `
            -ExpiryTime (Get-Date).AddMinutes(10) `
            -Verbose

    # Iterate containers in parallel, deploy token for each.
    ForEach -Parallel ($container in (Get-AzureStorageContainer -Context $context).Name) {
        Sequence {
            Write-Verbose "Generating token for container $container..."
            New-AzureRmResourceGroupDeployment -Name "$($container)LocationSasToken" `
                -ResourceGroupName management `
                -Mode Incremental `
                -TemplateUri "$($context.BlobEndPoint)resources/secrets.json$($resourcesLocationSasToken)" `
                -TemplateParameterObject @{ 
                    vaultName = $vault
                    secretName = "$($container)LocationSasToken"
                    value = (New-AzureStorageContainerSASToken -Context $context `
                        -Container $container `
                        -Permission r `
                        -ExpiryTime (Get-Date).AddHours(8) `
                        -Verbose).ToString()
                    }
        }
    }
}