
# ==========================================
# Mozilla Firefox - Current User Installer
# Windows 10 / Windows 11
# No Administrator elevation requested
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\Firefox-Installer"
$Installer = "$Folder\FirefoxSetup.exe"

# Mozilla official latest 64-bit English installer
$Url = "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US"

try {
    # Create folder
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    Write-Host "Downloading Mozilla Firefox..." -ForegroundColor Cyan

    & curl.exe -fL --retry 5 --retry-delay 3 `
        --connect-timeout 30 `
        $Url -o $Installer

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path $Installer) -or
        (Get-Item $Installer).Length -lt 10MB) {
        throw "Firefox download failed."
    }

    Write-Host "Download completed." -ForegroundColor Green

    # Verify Mozilla digital signature
    $Signature = Get-AuthenticodeSignature $Installer

    if ($Signature.Status -ne "Valid" -or
        $Signature.SignerCertificate.Subject -notmatch "Mozilla") {
        throw "Mozilla digital signature verification failed."
    }

    Write-Host "Signature verified." -ForegroundColor Green

    # Install under current user
    Write-Host "Installing Firefox..." -ForegroundColor Yellow

    $Process = Start-Process `
        -FilePath $Installer `
        -ArgumentList "/S" `
        -Wait -PassThru

    # Verify installation
    $FirefoxPaths = @(
        "$env:LOCALAPPDATA\Programs\Mozilla Firefox\firefox.exe",
        "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
    )

    $Firefox = $FirefoxPaths |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1

    if ($Firefox) {
        Write-Host "Firefox installed successfully!" -ForegroundColor Green
        Write-Host "Location: $Firefox"
        Start-Process $Firefox
    }
    else {
        Write-Host "Firefox installation not detected." -ForegroundColor Yellow
        Write-Host "Installer exit code: $($Process.ExitCode)"
    }

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
