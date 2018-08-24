class Token {
    [string] $Name

    [string] $SASToken

    Token([string] $Name, [string] $Container, [object] $Context) {
        $this.Name = $Name
        $this.SASToken = New-AzureStorageContainerSASToken -Context $Context `
                -Container $Container `
                -Permission r `
                -ExpiryTime (Get-Date).AddHours(4) `
                -Verbose;
    }

    [object] GetToken() {
        return @{
            name = $this.Name
            value = $this.SASToken
        }
    }
}