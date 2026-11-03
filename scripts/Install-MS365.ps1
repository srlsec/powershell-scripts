
# ==========================================
# Microsoft 365 Home - Online Installer
# Official Microsoft download
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\MS365-Installer"
$Installer = "$Folder\OfficeSetup.exe"

$Url = "https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=O365HomePremRetail&language=en-us&platform=def&version=O16GA&source=MktDownloadForWinPage"

try {
    # Create folder
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    # Download
    Write-Host "Downloading Microsoft 365..." -ForegroundColor Cyan

    & curl.exe -fL --retry 5 --retry-delay 3 `
        --connect-timeout 30 `
        $Url -o $Installer

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path $Installer) -or
        (Get-Item $Installer).Length -lt 1MB) {
        throw "Microsoft 365 download failed."
    }

    # Verify digital signature
    Write-Host "Verifying installer..." -ForegroundColor Cyan

    $Signature = Get-AuthenticodeSignature $Installer

    if ($Signature.Status -ne "Valid" -or
        $Signature.SignerCertificate.Subject -notmatch "Microsoft") {
        throw "Microsoft installer signature verification failed."
    }

    Write-Host "Signature verified." -ForegroundColor Green

    # Start installation
    Write-Host "Starting Microsoft 365 setup..." -ForegroundColor Yellow

    Start-Process -FilePath $Installer

    Write-Host "Microsoft 365 installer launched." -ForegroundColor Green
    Write-Host "Follow the installation instructions."

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
