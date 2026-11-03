
# ==========================================
# Google Chrome - Automatic Installer
# Current User | Windows 10/11 64-bit
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\Chrome-Installer"
$Installer = "$Folder\ChromeStandaloneSetup64.exe"

$Url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"

try {
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    Write-Host "Downloading Google Chrome..." -ForegroundColor Cyan

    & curl.exe -fL --retry 5 --retry-delay 3 `
        --connect-timeout 30 `
        $Url -o $Installer

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path $Installer) -or
        (Get-Item $Installer).Length -lt 10MB) {
        throw "Chrome download failed."
    }

    Write-Host "Download completed." -ForegroundColor Green

    # Verify Google signature
    $Signature = Get-AuthenticodeSignature $Installer

    if ($Signature.Status -ne "Valid" -or
        $Signature.SignerCertificate.Subject -notmatch "Google") {
        throw "Google signature verification failed."
    }

    Write-Host "Signature verified." -ForegroundColor Green

    # Launch installer
    Write-Host "Starting Chrome installation..." -ForegroundColor Yellow

    $Process = Start-Process -FilePath $Installer -PassThru

    Write-Host "Chrome installer launched." -ForegroundColor Green
    Write-Host "Complete the installation if prompted."

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
