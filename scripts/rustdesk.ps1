
# ============================================
# RustDesk - Automatic Download & Installation
# ============================================

$Folder = "C:\RemoteTools"
$Installer = "$Folder\RustDesk-Setup.exe"
$Api = "https://api.github.com/repos/rustdesk/rustdesk/releases/latest"

New-Item -ItemType Directory -Path $Folder -Force | Out-Null

try {
    Write-Host "Fetching latest RustDesk release..." -ForegroundColor Cyan

    $Release = Invoke-RestMethod `
        -Uri $Api `
        -Headers @{
            "User-Agent" = "PowerShell-RustDesk-Installer"
            "Accept" = "application/vnd.github+json"
        }

    $Architecture = if ([Environment]::Is64BitOperatingSystem) {
        if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
            "aarch64"
        } else {
            "x86_64"
        }
    } else {
        "i686"
    }

    $Asset = $Release.assets |
        Where-Object {
            $_.name -match "\.exe$" -and
            $_.name -match $Architecture
        } |
        Select-Object -First 1

    if (-not $Asset) {
        throw "No matching Windows installer found."
    }

    Write-Host "Version: $($Release.tag_name)" -ForegroundColor Green
    Write-Host "Downloading: $($Asset.name)" -ForegroundColor Yellow

    & curl.exe -fL --retry 5 --retry-delay 3 `
        --connect-timeout 30 `
        -A "Mozilla/5.0" `
        $Asset.browser_download_url `
        -o $Installer

    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path $Installer) -or
        (Get-Item $Installer).Length -lt 1MB) {
        throw "RustDesk download failed."
    }

    Write-Host "Download completed." -ForegroundColor Green

    Write-Host "Starting RustDesk installation..." -ForegroundColor Yellow

    $Process = Start-Process `
        -FilePath $Installer `
        -ArgumentList "--silent-install" `
        -Wait -PassThru

    Write-Host "Installer exit code: $($Process.ExitCode)" -ForegroundColor Cyan

    if ($Process.ExitCode -ne 0) {
        throw "RustDesk installation failed."
    }

    Write-Host "RustDesk installed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
