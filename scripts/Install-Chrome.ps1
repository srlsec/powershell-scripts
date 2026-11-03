
# ==========================================
# Google Chrome - Standard User Installation
# Windows 10 / Windows 11
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\Chrome-Installer"
$Installer = "$Folder\ChromeStandaloneSetup64.exe"
$ChromePath = "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"

$Url = "https://dl.google.com/chrome/direct/ChromeStandaloneSetup64.exe"

try {
    # Create folder
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    # Check existing installation
    if (Test-Path $ChromePath) {
        Write-Host "Chrome already installed for current user." -ForegroundColor Green
        Start-Process $ChromePath
        exit 0
    }

    # Download
    Write-Host "Downloading Google Chrome..." -ForegroundColor Cyan

    & curl.exe -fL --retry 5 --retry-delay 3 `
        --connect-timeout 30 `
        $Url -o $Installer

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path $Installer) -or
        (Get-Item $Installer).Length -lt 10MB) {
        throw "Chrome download failed."
    }

    # Verify signature
    $Signature = Get-AuthenticodeSignature $Installer

    if ($Signature.Status -ne "Valid" -or
        $Signature.SignerCertificate.Subject -notmatch "Google") {
        throw "Invalid Google installer signature."
    }

    Write-Host "Download verified." -ForegroundColor Green

    # Run in current user context
    Write-Host "Installing Chrome for current user..." -ForegroundColor Yellow

    $Process = Start-Process `
        -FilePath $Installer `
        -PassThru `
        -Wait

    if ($Process.ExitCode -ne 0) {
        throw "Installer exit code: $($Process.ExitCode)"
    }

    # Verify installation
    if (Test-Path $ChromePath) {
        Write-Host "Chrome installed successfully!" -ForegroundColor Green
        Start-Process $ChromePath
    }
    else {
        throw "Chrome executable not found. Check installation restrictions."
    }

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
