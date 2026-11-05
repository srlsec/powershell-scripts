
# ==========================================
# UltraViewer - Current User Download & Run
# Windows 10 / Windows 11
# No Explicit Administrator Elevation
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\Programs\UltraViewer"
$Installer = "$env:TEMP\UltraViewer_Setup.exe"

try {
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    # Official UltraViewer download URL
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

    # Verify digital signature
    $Signature = Get-AuthenticodeSignature -FilePath $Installer

    if ($Signature.Status -ne "Valid") {
        throw "Installer signature is not valid. Status: $($Signature.Status)"
    }

    if (-not $Signature.SignerCertificate) {
        throw "Publisher certificate is missing."
    }

    Write-Host "Signature verified." -ForegroundColor Green
    Write-Host "Publisher: $($Signature.SignerCertificate.Subject)" -ForegroundColor Gray

    # Launch installer without explicitly requesting elevation
    Write-Host "Launching UltraViewer setup..." -ForegroundColor Yellow

    $Process = Start-Process -FilePath $Installer -PassThru

    Write-Host "Setup launched successfully." -ForegroundColor Green
    Write-Host "Process ID: $($Process.Id)" -ForegroundColor Gray
    Write-Host "Complete the installation if prompted."

    Write-Host "Administrator permission may still be required by the installer." -ForegroundColor Yellow
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
