# Windows Optimization Script
# Run as Administrator

Write-Host "=== Windows Optimization Script ===" -ForegroundColor Cyan
Write-Host "Running system optimizations..." -ForegroundColor Yellow

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "This script requires Administrator privileges!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    pause
    exit
}

# 1. DISABLE VISUAL EFFECTS FOR BETTER PERFORMANCE
Write-Host "`n[1/10] Optimizing visual effects..." -ForegroundColor Green
$visualEffects = @(
    "AnimationControls",
    "AnimationOrbit",
    "AnimationShadows",
    "AnimationStartMenu",
    "AnimationTaskbar",
    "AnimationWindow",
    "DisableOverlappedContent",
    "DisableShadow",
    "DisableThumbnailCache",
    "EnableTransparency",
    "FadeMenu",
    "FadeOut",
    "ListBoxSmoothScrolling",
    "ListviewAlphaSelect",
    "ListviewShadow",
    "MenuAnimation",
    "SelectionFade",
    "TaskbarAnimations",
    "TooltipAnimation",
    "UITrack"
)

foreach ($effect in $visualEffects) {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name $effect -Value 0 -ErrorAction SilentlyContinue
}

# Set visual effects to "Adjust for best performance"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2

# 2. DISABLE UNNECESSARY SERVICES
Write-Host "`n[2/10] Disabling unnecessary services..." -ForegroundColor Green
$servicesToDisable = @(
    "Fax",                    # Fax service
    "MapsBroker",             # Downloaded Maps Manager
    "lfsvc",                  # Geolocation Service
    "SharedAccess",           # Internet Connection Sharing
    "SysMain",                # Superfetch (modern systems)
    "TrkWks",                 # Distributed Link Tracking Client
    "WMPNetworkSvc",          # Windows Media Player Network Sharing
    "WSearch",                # Windows Search (disable if you don't use search)
    "XblAuthManager",         # Xbox Live Auth Manager
    "XblGameSave",            # Xbox Live Game Save
    "XboxNetApiSvc"           # Xbox Live Networking Service
)

foreach ($service in $servicesToDisable) {
    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
    Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "  Disabled: $service" -ForegroundColor Gray
}

# 3. DISABLE AUTOMATIC APP STARTUP
Write-Host "`n[3/10] Cleaning startup programs..." -ForegroundColor Green
# Remove common startup programs (customize this list)
$startupPaths = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
)

foreach ($path in $startupPaths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Filter *.lnk | ForEach-Object {
            Write-Host "  Found startup item: $($_.Name)" -ForegroundColor Gray
        }
    }
}

# 4. CLEAR TEMPORARY FILES
Write-Host "`n[4/10] Cleaning temporary files..." -ForegroundColor Green
$tempFolders = @(
    "$env:TEMP",
    "$env:WINDIR\Temp",
    "C:\Windows\Prefetch",
    "$env:LOCALAPPDATA\Temp"
)

foreach ($folder in $tempFolders) {
    if (Test-Path $folder) {
        Remove-Item -Path "$folder\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Cleaned: $folder" -ForegroundColor Gray
    }
}

# Clean Recycle Bin
$shell = New-Object -ComObject Shell.Application
$shell.NameSpace(0xA).Items() | ForEach-Object { 
    Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue 
}

# 5. DISABLE TELEMETRY AND DIAGNOSTICS
Write-Host "`n[5/10] Reducing telemetry and diagnostics..." -ForegroundColor Green
$telemetryPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
)

foreach ($path in $telemetryPaths) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
    Set-ItemProperty -Path $path -Name "AllowTelemetry" -Value 0 -Type DWord
}

# Disable Cortana (Windows 10/11)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -ErrorAction SilentlyContinue

# 6. OPTIMIZE POWER SETTINGS FOR PERFORMANCE
Write-Host "`n[6/10] Optimizing power settings..." -ForegroundColor Green
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c  # High Performance plan
powercfg -change -monitor-timeout-ac 0
powercfg -change -disk-timeout-ac 0
powercfg -change -standby-timeout-ac 0
powercfg -change -hibernate-timeout-ac 0

# 7. OPTIMIZE NETWORK SETTINGS
Write-Host "`n[7/10] Optimizing network settings..." -ForegroundColor Green
# Disable Windows Auto-Tuning
netsh int tcp set global autotuninglevel=disabled

# Optimize TCP parameters
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "Tcp1323Opts" -Value 1
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "DefaultTTL" -Value 64
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "EnablePMTUDiscovery" -Value 1
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "EnablePMTUBHDetect" -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "SackOpts" -Value 1
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpMaxDataRetransmissions" -Value 5

# 8. DISABLE TIPS AND ADVERTISEMENTS
Write-Host "`n[8/10] Disabling tips and ads..." -ForegroundColor Green
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "ContentDeliveryAllowed" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "OemPreInstalledAppsEnabled" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEnabled" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEverEnabled" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338387Enabled" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353698Enabled" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0

# 9. DISABLE GAME BAR AND CAPTURES
Write-Host "`n[9/10] Disabling Game Bar and captures..." -ForegroundColor Green
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "ShowStartupPanel" -Value 0

# 10. FINAL OPTIMIZATIONS AND CLEANUP
Write-Host "`n[10/10] Performing final optimizations..." -ForegroundColor Green

# Clear Windows Event Logs (optional)
Get-WinEvent -ListLog * | Where-Object {$_.RecordCount} | ForEach-Object {
    [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($_.LogName)
}

# Flush DNS
ipconfig /flushdns

# Restart Windows Explorer to apply changes
Write-Host "`nRestarting Windows Explorer..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force
Start-Process explorer.exe

# Run Disk Cleanup
Write-Host "`nRunning Disk Cleanup (silent)..." -ForegroundColor Yellow
cleanmgr /sagerun:1 | Out-Null

Write-Host "`n=== Optimization Complete! ===" -ForegroundColor Green
Write-Host "Recommendations:" -ForegroundColor Cyan
Write-Host "1. Restart your computer to apply all changes" -ForegroundColor Yellow
Write-Host "2. Consider disabling unnecessary startup programs in Task Manager" -ForegroundColor Yellow
Write-Host "3. Regularly run this script for maintenance" -ForegroundColor Yellow
Write-Host "4. Keep Windows and drivers updated" -ForegroundColor Yellow

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")