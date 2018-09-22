using module .\Certificate.psm1
class Pfx: Certificate {

    hidden [string] $Password

    Pfx([string] $Name): base($Name) {
        $this.Password = (New-Guid).ToString("N")
        $this.ExportCertificate()
    }

    <# .Description Creates temp directory, exports pfx to temp. #>
    [void] ExportCertificate() {
        Export-PfxCertificate -Cert $this.Certificate `
            -FilePath "$($this.Temp)\$($this.Name).pfx" `
            -Password (ConvertTo-SecureString -AsPlainText -Force $this.Password)
    }

    <# .Description Returns password in secret format. #>
    [object] GetPassword() {
        return @{
            name = "$($this.Name)Password"
            value = $this.Password
        }
    }
}