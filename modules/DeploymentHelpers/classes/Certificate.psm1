class Certificate {
    [string] $Name
    
    hidden [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate
    
    hidden [string] $Temp = "$($env:TEMP)\~$([System.IO.Path]::GetRandomFileName().Split('.')[0])"
    
    hidden [string] $CertStoreLocation = "Cert:\CurrentUser\My"

    hidden [string] $Thumbprint

    hidden [string] $Base64Value

    Certificate([string] $Name) {
        $this.Name = $Name
        $this.GenerateCertificate()
        New-Item -Type Directory -Path $this.Temp
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

    <# .Description Returns certificate in object format. #>
    [void] ExportCertificate() {
        Export-Certificate -Cert $this.Certificate `
            -FilePath "$($this.Temp)\$($this.Name).cer"
    }

    <# .Description Returns certificate in object format. #>
    [string] GetEndDate() {
        return $this.Certificate.NotAfter
    }

    <# .Description Returns the certificate start date. #>
    [string] GetStartDate() {
        return $this.Certificate.NotBefore
    }

    [string] GetPath() {
        return $this.Temp
    }

    <# .Description Removes the generated certificate. #>
    [void] RemoveCertificate() {
        Remove-Item $this.Certificate.PSPath
        Remove-Item $this.Temp -Recurse
    }
}