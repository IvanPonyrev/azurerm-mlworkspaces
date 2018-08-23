class Certificate {
    [string] $Name

    hidden [string] $CertStoreLocation = "Cert:\CurrentUser\My"

    hidden [string] $FilePath = "$($env:TEMP)~$([System.IO.Path]::GetRandomFileName().Split('.')[0])"

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

        New-Item -ItemType Directory -Path $this.FilePath
        $cer = Export-Certificate -Cert $certificate `
            -FilePath "$($this.Filepath)\$($this.Name).cer"

        certutil.exe -encode $cer "$($this.Filepath)\$($this.Name)Encoded.cer"

        $this.Base64Value = Get-Content "$($this.Filepath)\$($this.Name)Encoded.cer" -Encoding Ascii
        $this.Thumbprint = $certificate.GetCertHash()
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