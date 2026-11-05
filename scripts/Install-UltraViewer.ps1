
# ==========================================
# UltraViewer - Download & Run
# Windows 10 / Windows 11
# Standard User Execution
# Publisher Name Verification: Disabled
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\Programs\UltraViewer"
$Installer = "$env:TEMP\UltraViewer_Setup.exe"

try {
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    $Url = "https://www.ultraviewer.net/en/UltraViewer_setup_6.6_en.exe"

    Write-Host "Downloading UltraViewer..." -ForegroundColor Cyan

    if (Test-Path $Installer) {
        Remove-Item $Installer -Force
    }

    & curl.exe -fL --retry 5 --retry-delay 3 `
        --connect-timeout 30 `
        $Url -o $Installer

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path $Installer) -or
        (Get-Item $Installer).Length -lt 1MB) {
        throw "Download failed or installer is invalid."
    }

    Write-Host "Download completed." -ForegroundColor Green

    # Digital signature validation only
    # No publisher-name matching
    $Signature = Get-AuthenticodeSignature -FilePath $Installer

    if ($Signature.Status -ne "Valid") {
        throw "Installer signature validation failed: $($Signature.Status)"
    }

    Write-Host "Digital signature is valid." -ForegroundColor Green

    # Launch without explicitly requesting administrator elevation
    Write-Host "Launching UltraViewer setup..." -ForegroundColor Yellow

    $Process = Start-Process -FilePath $Installer -PassThru

    Write-Host "UltraViewer setup launched." -ForegroundColor Green
    Write-Host "Process ID: $($Process.Id)" -ForegroundColor Gray

    Write-Host "Complete the installation if prompted." -ForegroundColor Yellow
    Write-Host "Administrator permission may still be required." -ForegroundColor Yellow
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
