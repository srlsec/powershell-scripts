
# ==========================================
# RustDesk 1.5.1 - Download & Install
# Windows 10 / Windows 11 (64-bit)
# Silent Installation
# No Explicit Administrator Elevation
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\RustDesk-Installer"
$Installer = "$Folder\rustdesk-1.5.1-x86_64.exe"

try {
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    # Official GitHub release URL
    $Url = "https://github.com/rustdesk/rustdesk/releases/download/1.5.1/rustdesk-1.5.1-x86_64.exe"

    Write-Host "Downloading RustDesk 1.5.1..." -ForegroundColor Cyan

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
    Write-Host "Installing RustDesk..." -ForegroundColor Yellow

    $Process = Start-Process -FilePath $Installer `
        -ArgumentList "--silent-install" `
        -Wait `
        -PassThru

    if ($Process.ExitCode -ne 0) {
        throw "RustDesk installation failed. Exit code: $($Process.ExitCode)"
    }

    # Check common installation locations
    $PossiblePaths = @(
        "$env:ProgramFiles\RustDesk\rustdesk.exe",
        "${env:ProgramFiles(x86)}\RustDesk\rustdesk.exe",
        "$env:LOCALAPPDATA\Programs\RustDesk\rustdesk.exe"
    )

    $App = $PossiblePaths |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1

    if ($App) {
        Write-Host "RustDesk installed successfully." -ForegroundColor Green
        Write-Host "Location: $App" -ForegroundColor Gray

        Start-Process -FilePath $App
    }
    else {
        Write-Host "Installation command completed, but RustDesk was not found in the expected locations." -ForegroundColor Yellow
    }

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
