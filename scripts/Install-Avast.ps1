
# ==========================================
# Avast Free Antivirus - Installer
# Current Windows User
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\Avast-Installer"
$Installer = "$Folder\AvastSetup.exe"

$Url = "https://bits.avcdn.net/productfamily_ANTIVIRUS/insttype_FREE/platform_WIN/installertype_ONLINE/build_RELEASE/cookie_mmm_ava_012_999_aak_m?ref=clid_1820503620.1793861930--gdid_aa80b590-e573-4b70-992e-9710ee6ef053--cmid_WDS~en-in~lp-ppc-free-av-brand~~hero~012_aak&alt=en-in"

try {
    # Create directory
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    # Download
    Write-Host "Downloading Avast Free Antivirus..." -ForegroundColor Cyan

    & curl.exe -fL --retry 5 --retry-delay 3 `
        --connect-timeout 30 `
        $Url -o $Installer

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path $Installer) -or
        (Get-Item $Installer).Length -lt 1MB) {
        throw "Avast download failed."
    }

    Write-Host "Download completed." -ForegroundColor Green

    # Verify digital signature
    $Signature = Get-AuthenticodeSignature $Installer

    if ($Signature.Status -ne "Valid" -or
        $Signature.SignerCertificate.Subject -notmatch "Avast") {
        throw "Avast publisher signature verification failed."
    }

    Write-Host "Digital signature verified." -ForegroundColor Green

    # Launch installer
    Write-Host "Launching Avast installer..." -ForegroundColor Yellow

    Start-Process -FilePath $Installer

    Write-Host "Avast installer launched successfully." -ForegroundColor Green
    Write-Host "Follow the installation instructions."

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
