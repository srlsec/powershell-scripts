
# ==========================================
# TeamViewer - Current User Download & Run
# Windows 10 / Windows 11 (64-bit)
# No Explicit Administrator Elevation
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\TeamViewer-Installer"
$Installer = "$Folder\TeamViewer_Setup_x64.exe"

try {
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    # Official TeamViewer download URL
    $Url = "https://download.teamviewer.com/download/version_15x/TeamViewer_Setup_x64.exe"

    Write-Host "Downloading TeamViewer..." -ForegroundColor Cyan

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
        throw "Installer signature validation failed: $($Signature.Status)"
    }

    if (-not $Signature.SignerCertificate -or
        $Signature.SignerCertificate.Subject -notmatch "TeamViewer") {
        throw "Unexpected installer publisher."
    }

    Write-Host "Publisher verified." -ForegroundColor Green

    # Launch installer
    Write-Host "Launching TeamViewer setup..." -ForegroundColor Yellow

    $Process = Start-Process -FilePath $Installer -PassThru

    Write-Host "TeamViewer setup launched." -ForegroundColor Green
    Write-Host "Process ID: $($Process.Id)" -ForegroundColor Gray
    Write-Host "Follow the installer instructions."

    Write-Host "Administrator permission may still be required." -ForegroundColor Yellow
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
