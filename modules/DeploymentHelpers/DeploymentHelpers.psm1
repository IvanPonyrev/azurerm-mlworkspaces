function New-AdApplication {
    Param(
        [string] [Parameter(Mandatory=$true)] $Name
    )
    return [AdApplication]::new($Name)
}

function New-Certificate {
    Param(
        [string] [Parameter(Mandatory=$true)] $Name    
    )
    return [Certificate]::new($Name)
}

function New-PfxCertificate {
    Param(
        [string] [Parameter(Mandatory=$true)] $Name    
    )
    return [Pfx]::new($Name)
}

function New-AutomationRunbook {
    Param(
        [string] [Parameter(Mandatory=$true)] $Name,    
        [string] [Parameter(Mandatory=$true)] $Frequency,    
        [int] [Parameter(Mandatory=$true)] $Interval
    )
    return [Runbook]::new($Name, $Frequency, $Interval)
}

function New-BlobStorageToken {
    Param(
        [string] [Parameter(Mandatory=$true)] $Name,    
        [string] [Parameter(Mandatory=$true)] $Container,    
        [object] [Parameter(Mandatory=$true)] $Context
    )
    return [Token]::new($Name, $Container, $Context)
}

function New-TemplateDeployment {
    Param(
        [string] [Parameter(Mandatory=$true)] $ResourceGroupName,
        [string] [Parameter(Mandatory=$true)] $TemplateFile,
        [string] [Parameter(Mandatory=$true)] $TemplateParametersFile      
    )
    return [Deployment]::new($ResourceGroupName, $TemplateFile, $TemplateParametersFile)
}