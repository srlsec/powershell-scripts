
# ==========================================
# Quick Heal Internet Security Installer
# Windows 10 / Windows 11
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\QuickHeal-Installer"
$Installer = "$Folder\QHISE.exe"

$Url = "https://download.quickheal.com/builds/2700/ise/QHISE.EXE"


try {
    # Create download directory
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    Write-Host "Downloading Quick Heal..." -ForegroundColor Cyan

    # Download installer
    & curl.exe -fL --retry 5 --retry-delay 3 `
        --connect-timeout 30 `
        $Url -o $Installer

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path $Installer) -or
        (Get-Item $Installer).Length -lt 1MB) {
        throw "Quick Heal download failed."
    }

    Write-Host "Download completed." -ForegroundColor Green

    # Verify digital signature
    $Signature = Get-AuthenticodeSignature $Installer

    if ($Signature.Status -ne "Valid" -or
        $Signature.SignerCertificate.Subject -notmatch "Quick Heal") {
        throw "Quick Heal publisher signature verification failed."
    }

    Write-Host "Digital signature verified." -ForegroundColor Green

    # Launch installer
    Write-Host "Launching Quick Heal installer..." -ForegroundColor Yellow

    Start-Process -FilePath $Installer

    Write-Host "Quick Heal installer launched successfully." -ForegroundColor Green
    Write-Host "Follow the installation instructions."

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
