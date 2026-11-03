
# ==========================================
# Brave Browser - Current User Installer
# No Administrator elevation requested
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\Brave-Installer"
$Installer = "$Folder\BraveSetup.exe"

$Url = "https://laptop-updates.brave.com/latest/winx64"

try {
    # Create folder
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    Write-Host "Downloading Brave Browser..." -ForegroundColor Cyan

    & curl.exe -fL --retry 5 --retry-delay 3 `
        --connect-timeout 30 `
        $Url -o $Installer

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path $Installer) -or
        (Get-Item $Installer).Length -lt 1MB) {
        throw "Brave download failed."
    }

    Write-Host "Download completed." -ForegroundColor Green

    # Verify digital signature
    $Signature = Get-AuthenticodeSignature $Installer

    if ($Signature.Status -ne "Valid" -or
        $Signature.SignerCertificate.Subject -notmatch "Brave") {
        throw "Brave digital signature verification failed."
    }

    Write-Host "Download verified." -ForegroundColor Green

    Write-Host "Launching Brave installer..." -ForegroundColor Yellow

    # Launch under current user privileges
    $Process = Start-Process -FilePath $Installer -PassThru -Wait

    # Check installation
    $Brave = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe"

    if (Test-Path $Brave) {
        Write-Host "Brave installed successfully!" -ForegroundColor Green
        Start-Process $Brave
    }
    else {
        Write-Host "Brave installation not detected." -ForegroundColor Yellow
        Write-Host "Installer exit code: $($Process.ExitCode)"
    }

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
