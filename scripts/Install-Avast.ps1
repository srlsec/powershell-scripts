
# ==========================================
# Avast Free Antivirus - Installer
# Current Windows User
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\Avast-Installer"
$Installer = "$Folder\AvastSetup.exe"

$Url = "https://bits.avcdn.net/productfamily_ANTIVIRUS/insttype_FREE/platform_WIN/installertype_ONLINE/build_RELEASE/cookie_mmm_ava_012_999_aak_m?ref=clid_1820503620.1793861930--gdid_aa80b590-e573-4b70-992e-9710ee6ef053--cmid_WDS~en-in~lp-ppc-free-av-brand~~hero~012_aak&alt=en-in"

try {
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    Write-Host "Downloading Avast Free Antivirus..." -ForegroundColor Cyan

    & curl.exe -fL --retry 5 --retry-delay 3 `
        --connect-timeout 30 `
        $Url -o $Installer

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path $Installer)) {
        throw "Avast download failed."
    }

    # Check file size
    $Size = (Get-Item $Installer).Length

    Write-Host "Downloaded size: $([math]::Round($Size / 1KB, 2)) KB" -ForegroundColor Cyan

    if ($Size -lt 50KB) {
        throw "Downloaded file is too small."
    }

    # Check executable file header
    $Stream = [System.IO.File]::OpenRead($Installer)

    try {
        $Header = New-Object byte[] 2
        [void]$Stream.Read($Header, 0, 2)
    }
    finally {
        $Stream.Dispose()
    }

    if ($Header[0] -ne 0x4D -or $Header[1] -ne 0x5A) {
        throw "Downloaded file is not a Windows executable (MZ header missing)."
    }

    # Verify digital signature
    Write-Host "Verifying Avast signature..." -ForegroundColor Cyan

    $Signature = Get-AuthenticodeSignature $Installer

    if ($Signature.Status -ne "Valid") {
        throw "Invalid digital signature: $($Signature.Status)"
    }

    if ($Signature.SignerCertificate.Subject -notmatch "Avast|Gen Digital") {
        throw "Unexpected publisher: $($Signature.SignerCertificate.Subject)"
    }

    Write-Host "Publisher: $($Signature.SignerCertificate.Subject)" -ForegroundColor Green
    Write-Host "Signature verified." -ForegroundColor Green

    # Launch installer
    Write-Host "Launching Avast installer..." -ForegroundColor Yellow

    Start-Process -FilePath $Installer

    Write-Host "Avast installer launched successfully." -ForegroundColor Green

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
