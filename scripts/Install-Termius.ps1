
# ==========================================
# Termius - Current User Download & Install
# Windows 10 / Windows 11
# Silent Installation
# No Explicit Administrator Elevation
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\Termius-Installer"
$Installer = "$Folder\Install Termius.exe"

try {
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    # Official Termius download URL
    $Url = "https://download.termius.com/windows/Install%20Termius.exe"

    Write-Host "Downloading Termius..." -ForegroundColor Cyan

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

    Write-Host "Digital signature is valid." -ForegroundColor Green

    # Silent installation
    Write-Host "Installing Termius..." -ForegroundColor Yellow

    $Process = Start-Process -FilePath $Installer `
        -ArgumentList "/S" `
        -Wait `
        -PassThru

    if ($Process.ExitCode -ne 0) {
        throw "Termius installation failed. Exit code: $($Process.ExitCode)"
    }

    # Check common per-user installation locations
    $PossiblePaths = @(
        "$env:LOCALAPPDATA\Programs\Termius\Termius.exe",
        "$env:LOCALAPPDATA\Termius\Termius.exe"
    )

    $App = $PossiblePaths |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1

    if ($App) {
        Write-Host "Termius installed successfully." -ForegroundColor Green
        Write-Host "Location: $App" -ForegroundColor Gray

        Start-Process -FilePath $App
    }
    else {
        Write-Host "Installer completed, but the application was not found in the expected locations." -ForegroundColor Yellow
        Write-Host "Check the Start Menu or installed applications." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
