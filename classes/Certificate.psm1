class Certificate {
    [string] $Name

    hidden [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate

    hidden [string] $CertStoreLocation = "Cert:\CurrentUser\My"

    hidden [string] $Thumbprint

    hidden [string] $Base64Value

    Certificate([string] $Name) {
        $this.Name = $Name
        $this.GenerateCertificate()
    }

    <# .Description Generates a certificate. #>
    [void] GenerateCertificate() {
        # Create certificate, export to temp directory, store base64Value and thumbprint.
        $this.Certificate = New-SelfSignedCertificate -Subject "CN=$($this.Name)" `
            -KeyAlgorithm RSA `
            -KeyLength 2048 `
            -Type CodeSigningCert `
            -CertStoreLocation $this.CertStoreLocation

        $this.Base64Value = [System.Convert]::ToBase64String($this.Certificate.RawData)
        $this.Thumbprint = $this.Certificate.Thumbprint
    }

    <# .Description Returns certificate in object format. #>
    [object] GetCertificate() {
        return @{
            name = $this.Name
            thumbprint = $this.Thumbprint
            base64Value = $this.Base64Value
        }
    }

    [string] GetEndDate() {
        return $this.Certificate.NotAfter
    }

    [string] GetStartDate() {
        return $this.Certificate.NotBefore
    }

    <# .Description Removes the generated certificate. #>
    [void] RemoveCertificate() {
        Remove-Item $this.Certificate.PSPath
    }
}