
# ==========================================
# Google Chrome Automatic Installer
# Windows 10 / Windows 11
# ==========================================

$ErrorActionPreference = "Stop"

$Folder = "$env:LOCALAPPDATA\Chrome-Installer"
$Installer = "$Folder\ChromeSetup.exe"

$Url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"

try {
    # Create folder
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null

    Write-Host "Downloading Google Chrome..." -ForegroundColor Cyan

    # Download installer
    & curl.exe -fL --retry 5 --retry-delay 3 `
        --connect-timeout 30 `
        $Url -o "$Folder\ChromeSetup.msi"

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path "$Folder\ChromeSetup.msi") -or
        (Get-Item "$Folder\ChromeSetup.msi").Length -lt 1MB) {
        throw "Chrome download failed."
    }

    $Installer = "$Folder\ChromeSetup.msi"

    # Verify signature
    $Signature = Get-AuthenticodeSignature $Installer

    if ($Signature.Status -ne "Valid" -or
        $Signature.SignerCertificate.Subject -notmatch "Google") {
        throw "Google digital signature verification failed."
    }

    Write-Host "Download verified." -ForegroundColor Green

    # Silent installation
    Write-Host "Installing Google Chrome..." -ForegroundColor Yellow

    $Process = Start-Process -FilePath "msiexec.exe" `
        -ArgumentList "/i `"$Installer`" /qn /norestart" `
        -Wait -PassThru

    if ($Process.ExitCode -notin @(0, 3010)) {
        throw "Chrome installation failed. Exit code: $($Process.ExitCode)"
    }

    Write-Host "Google Chrome installed successfully!" -ForegroundColor Green

    # Verify installation
    $ChromePaths = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    )

    $Chrome = $ChromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($Chrome) {
        Write-Host "Installed at: $Chrome" -ForegroundColor Green
    }

}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
