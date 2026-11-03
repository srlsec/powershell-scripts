
# ==========================================
# Google Chrome - Current User Installer
# No Administrator elevation requested
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\Chrome-Installer"
$Installer = "$Folder\googlechromestandaloneenterprise64.msi"

$Url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"

try {
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    Write-Host "Downloading Google Chrome..." -ForegroundColor Cyan

    & curl.exe -fL --retry 5 --retry-delay 3 `
        --connect-timeout 30 `
        $Url -o $Installer

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path $Installer) -or
        (Get-Item $Installer).Length -lt 1MB) {
        throw "Chrome download failed."
    }

    # Verify Google signature
    $Signature = Get-AuthenticodeSignature $Installer

    if ($Signature.Status -ne "Valid" -or
        $Signature.SignerCertificate.Subject -notmatch "Google") {
        throw "Google signature verification failed."
    }

    Write-Host "Download verified." -ForegroundColor Green

    Write-Host "Launching Chrome installer..." -ForegroundColor Yellow

    # Launch under current user's privileges
    Start-Process -FilePath $Installer

    Write-Host "Chrome installer launched." -ForegroundColor Green
    Write-Host "Complete installation if prompted."

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
