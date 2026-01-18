<#
.SYNOPSIS
    Reset AnyDesk configuration by moving config files to backup folder
.DESCRIPTION
    This script moves AnyDesk configuration files to a backup folder to reset AnyDesk settings
.PARAMETER BackupPath
    Custom backup location (default: creates timestamped folder in C:\ProgramData\)
.EXAMPLE
    .\reset-anydesk.ps1
.EXAMPLE
    .\reset-anydesk.ps1 -BackupPath "D:\Backups\AnyDesk"
#>

param(
    [string]$BackupPath
)

# Configuration
$anydeskPath = "C:\ProgramData\AnyDesk"
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

# Set backup path
if ([string]::IsNullOrEmpty($BackupPath)) {
    $BackupPath = "C:\ProgramData\AnyDesk_Backup_$timestamp"
}

# Files to move
$filesToMove = @(
    "service.conf",
    "service.conf.lock",
    "system.conf",
    "system.conf.lock"
)

# Function to test prerequisites
function Test-Prerequisites {
    if (-not (Test-Path -Path $anydeskPath)) {
        Write-Host "AnyDesk directory not found at: $anydeskPath" -ForegroundColor Red
        Write-Host "Please check if AnyDesk is installed." -ForegroundColor Yellow
        return $false
    }
    
    # Check if running as administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Host "Warning: Not running as administrator. Some operations might fail." -ForegroundColor Yellow
    }
    
    return $true
}

# Main execution
Clear-Host
Write-Host "AnyDesk Configuration Reset Utility" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Files will be MOVED (not copied) to backup folder" -ForegroundColor Yellow
Write-Host ""

# Test prerequisites
if (-not (Test-Prerequisites)) {
    exit 1
}

# Create backup directory
try {
    if (-not (Test-Path -Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
        Write-Host "Created backup directory: $BackupPath" -ForegroundColor Green
    }
}
catch {
    Write-Host "Failed to create backup directory: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Starting file move process..." -ForegroundColor White
Write-Host ""

# Move each file
$movedCount = 0
$failCount = 0
$notFoundCount = 0

foreach ($file in $filesToMove) {
    $source = Join-Path -Path $anydeskPath -ChildPath $file
    $destination = Join-Path -Path $BackupPath -ChildPath $file
    
    if (Test-Path -Path $source) {
        try {
            # Move the file
            Move-Item -Path $source -Destination $destination -Force -ErrorAction Stop
            
            Write-Host "  [MOVED] $file" -ForegroundColor Green
            $movedCount++
        }
        catch {
            Write-Host "  [ERROR] $file : $_" -ForegroundColor Red
            $failCount++
        }
    }
    else {
        Write-Host "  [NOT FOUND] $file" -ForegroundColor Yellow
        $notFoundCount++
    }
}

# Display summary
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "OPERATION SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""
Write-Host "Successfully moved: $movedCount file(s)" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "Failed to move: $failCount file(s)" -ForegroundColor Red
}
if ($notFoundCount -gt 0) {
    Write-Host "Not found: $notFoundCount file(s)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Backup location: $BackupPath" -ForegroundColor Yellow

# Show what's left in AnyDesk folder
Write-Host ""
Write-Host "Files remaining in AnyDesk folder:" -ForegroundColor Cyan
$remainingFiles = Get-ChildItem -Path $anydeskPath -ErrorAction SilentlyContinue
if ($remainingFiles) {
    $remainingFiles | ForEach-Object {
        Write-Host "  $($_.Name)" -ForegroundColor Gray
    }
} else {
    Write-Host "  (folder is empty)" -ForegroundColor Gray
}

# Ask to open backup folder
Write-Host ""
$openFolder = Read-Host "Open backup folder? (Y/N)"
if ($openFolder -eq 'Y' -or $openFolder -eq 'y') {
    Invoke-Item $BackupPath
}

Write-Host ""
Write-Host "AnyDesk configuration has been reset!" -ForegroundColor Green
Write-Host "AnyDesk will create new configuration files on next restart." -ForegroundColor Yellow