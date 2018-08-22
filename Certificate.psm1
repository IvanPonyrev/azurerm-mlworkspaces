class Certificate {
    [string] $Name

    [string] $Subject

    hidden [string] $CertStoreLocation = "Cert:\CurrentUser\My"

    hidden [string] $FilePath = "$([System.IO.Path]::GetTempPath())~$([System.IO.Path]::GetRandomFileName().Split('.')[0])"

    hidden [securestring] $Password

    hidden [securestring] $Thumbprint

    hidden [securestring] $Base64Value

    Certificate([string] $Name, [string] $Subject) {
        $this.Name = $Name
        $this.Subject = $Subject
        $this.Password = (New-Guid).ToString("N")
        $this.GenerateCertificate()
    }

    <# .Description Generates a certificate. #>
    hidden [void] GenerateCertificate([string] $VaultName) {
        # Create certificate, export to temp directory, store base64Value and thumbprint.
        $certificate = New-SelfSignedCertificate -Subject $this.Subject `
            -KeyAlgorithm RSA `
            -KeyLength 2048 `
            -Type CodeSigningCert `
            -CertStoreLocation $this.CertStoreLocation
        $this.Thumbprint = $certificate.Thumbprint

        $pfx = Export-PfxCertificate -Cert $certificate `
            -FilePath "$($this.Filepath)\$($this.Name).pfx" `
            -Password $this.Password
        $content = Get-Content $pfx -Encoding Byte
        $this.Base64Value = [System.Convert]::ToBase64String($content)
    }

    <# .Description Returns certificate in object format. #>
    [object] GetCertificate() {
        return @{
            name = $this.Name
            thumbprint = $this.Thumbprint
            base64Value = $this.Base64Value
        }
    }

    <# .Description Returns password in secret format. #>
    [object] GetPassword() {
        return @{
            name = "$($this.Name)CertificatePassword"
            value = $this.Password
        }
    }

    <# .Description Removes the generated certificate. #>
    [void] RemoveCertificate() {
        Remove-Item "$($this.CertStoreLocation)\$($this.Thumbprint)"
        Remove-Item $this.FilePath -Force -Recurse
    }
}