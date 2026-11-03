
# ==========================================
# AnyDesk Portable - Current User
# No Administrator privileges required
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\Programs\AnyDesk"
$Installer = "$Folder\AnyDesk.exe"

try {
    # Create user directory
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    # Download
    Write-Host "Downloading AnyDesk..." -ForegroundColor Cyan

    & curl.exe -fL --retry 5 --retry-delay 3 `
        "https://download.anydesk.com/AnyDesk.exe" `
        -o $Installer

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path $Installer) -or
        (Get-Item $Installer).Length -lt 1MB) {
        throw "Download failed."
    }

    # Verify publisher
    $Signature = Get-AuthenticodeSignature $Installer

    if ($Signature.Status -ne "Valid" -or
        $Signature.SignerCertificate.Subject -notmatch "AnyDesk") {
        throw "Invalid AnyDesk digital signature."
    }

    Write-Host "Download verified." -ForegroundColor Green

    # Launch portable version (NO --install)
    Write-Host "Starting AnyDesk..." -ForegroundColor Yellow

    Start-Process -FilePath $Installer

    Write-Host "`nAnyDesk started successfully!" -ForegroundColor Green
    Write-Host "Location: $Installer"

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
