
# ==========================================
# Avast Free Antivirus - Auto Downloader
# Windows 10 / Windows 11
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\Avast-Installer"
$Installer = "$Folder\avast_free_antivirus_setup_online.exe"

$Url = "https://bits.avcdn.net/insttype_FREE"

try {
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    Write-Host "Downloading Avast Free Antivirus..." -ForegroundColor Cyan

    & curl.exe -fL --retry 5 --retry-delay 3 `
        --connect-timeout 30 `
        $Url -o $Installer

    $CurlExit = $LASTEXITCODE

    if ($CurlExit -ne 0 -or -not (Test-Path $Installer)) {
        throw "Download failed. Curl exit code: $CurlExit"
    }

    # Check file size
    $Size = (Get-Item $Installer).Length

    Write-Host "Downloaded: $([math]::Round($Size / 1KB, 2)) KB" -ForegroundColor Cyan

    if ($Size -lt 50KB) {
        throw "Downloaded file is too small."
    }

    # Check executable header
    $Stream = [System.IO.File]::OpenRead($Installer)

    try {
        $Header = New-Object byte[] 2
        [void]$Stream.Read($Header, 0, 2)
    }
    finally {
        $Stream.Dispose()
    }

    if ($Header[0] -ne 0x4D -or $Header[1] -ne 0x5A) {
        throw "Downloaded file is not a Windows executable."
    }

    # Verify digital signature
    Write-Host "Verifying Avast signature..." -ForegroundColor Cyan

    $Signature = Get-AuthenticodeSignature $Installer

    if ($Signature.Status -ne "Valid" -or
        $Signature.SignerCertificate.Subject -notmatch "Avast|Gen Digital") {
        throw "Publisher verification failed: $($Signature.Status)"
    }

    Write-Host "Signature verified." -ForegroundColor Green

    # Launch installer
    Write-Host "Launching Avast installer..." -ForegroundColor Yellow

    Start-Process -FilePath $Installer

    Write-Host "Avast installer launched successfully!" -ForegroundColor Green

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
