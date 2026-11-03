
# ==========================================
# UltraViewer - Current User Download & Run
# Windows 10 / Windows 11
# No Administrator privileges requested
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\Programs\UltraViewer"
$Installer = "$env:TEMP\UltraViewer_Setup.exe"
$App = "$Folder\UltraViewer.exe"

try {
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    Write-Host "Downloading UltraViewer..." -ForegroundColor Cyan

    $Url = "https://www.ultraviewer.net/en/UltraViewer_setup_6.6_en.exe"

    & curl.exe -fL --retry 5 --retry-delay 3 `
        $Url -o $Installer

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path $Installer) -or
        (Get-Item $Installer).Length -lt 1MB) {
        throw "Download failed."
    }

    Write-Host "Download completed." -ForegroundColor Green

    # Verify digital signature
    $Signature = Get-AuthenticodeSignature $Installer

    if ($Signature.Status -ne "Valid") {
        throw "Installer signature is not valid."
    }

    if ($Signature.SignerCertificate.Subject -notmatch "UltraViewer|DucFabulous") {
        throw "Unexpected installer publisher."
    }

    Write-Host "Publisher verified." -ForegroundColor Green

    # UltraViewer does not document a supported per-user
    # portable installation command.
    Write-Host "Launching UltraViewer setup..." -ForegroundColor Yellow

    Start-Process -FilePath $Installer

    Write-Host "Setup launched. Follow the installer instructions." -ForegroundColor Green
    Write-Host "If administrator permission is requested, it is required by the installer."

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
