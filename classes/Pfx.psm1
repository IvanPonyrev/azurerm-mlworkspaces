using module .\Certificate.psm1
class Pfx: Certificate {
    hidden [string] $Temp = "$($env:TEMP)\~$([System.IO.Path]::GetRandomFileName().Split('.')[0])"

    hidden [string] $Password

    Pfx([string] $Name): base($Name) {
        $this.Password = (New-Guid).ToString("N")
        $this.ExportPfx()
    }

    <# .Description Creates temp directory, exports pfx to temp. #>
    [void] ExportPfx() {
        New-Item -Type Directory -Path $this.Temp
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

    [string] GetPath() {
        return "$($this.Temp)\$($this.Name).pfx"
    }

    <# .Description Removes the generated certificate. #>
    [void] RemoveCertificate() {
        ([Certificate]$this).RemoveCertificate()
        Remove-Item $this.Temp -Recurse
    }
}