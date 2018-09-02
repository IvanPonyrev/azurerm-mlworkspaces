class Certificate {
    [string] $Name

    hidden [string] $CertStoreLocation = "Cert:\CurrentUser\My"

    hidden [string] $Password

    hidden [string] $Thumbprint

    hidden [string] $Base64Value

    Certificate([string] $Name) {
        $this.Name = $Name
        $this.Password = (New-Guid).ToString("N")

        $this.GenerateCertificate()
    }

    <# .Description Generates a certificate. #>
    hidden [void] GenerateCertificate() {
        # Create certificate, export to temp directory, store base64Value and thumbprint.
        $certificate = New-SelfSignedCertificate -Subject "CN=$($this.Name)" `
            -KeyAlgorithm RSA `
            -KeyLength 2048 `
            -Type CodeSigningCert `
            -CertStoreLocation $this.CertStoreLocation

        $this.Base64Value = [System.Convert]::ToBase64String($certificate.RawData)
        $this.Thumbprint = $certificate.Thumbprint
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
    }
}