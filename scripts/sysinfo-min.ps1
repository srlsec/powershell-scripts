
# ==========================================
# SYSTEM INFORMATION REPORT
# Hardware & User Inventory
# ==========================================

$CS       = Get-CimInstance Win32_ComputerSystem
$Board    = Get-CimInstance Win32_BaseBoard
$Chassis  = Get-CimInstance Win32_SystemEnclosure
$CPU      = Get-CimInstance Win32_Processor
$RAM      = Get-CimInstance Win32_PhysicalMemory
$OS       = Get-CimInstance Win32_OperatingSystem
$Disks    = Get-CimInstance Win32_DiskDrive

Write-Host ""
Write-Host "==============================================="
Write-Host "           SYSTEM INFORMATION REPORT"
Write-Host "==============================================="

# Vendor & Model
Write-Host "`nSYSTEM INFORMATION"
Write-Host "------------------"

Write-Host "System Vendor:      $($CS.Manufacturer)"
Write-Host "Device Model:       $($CS.Model)"
Write-Host "System Family:      $($CS.SystemFamily)"
Write-Host "Board Serial:       $($Board.SerialNumber)"
Write-Host "Chassis Serial:     $($Chassis.SerialNumber)"

# CPU
Write-Host "`nPROCESSOR INFORMATION"
Write-Host "---------------------"

Write-Host "Name: $($CPU.Name.Trim())"
Write-Host "  Cores: $($CPU.NumberOfCores)"
Write-Host "  Logical Processors: $($CPU.NumberOfLogicalProcessors)"
Write-Host "  Max Clock Speed: $($CPU.MaxClockSpeed) MHz"

# RAM
$TotalRAM = ($RAM | Measure-Object -Property Capacity -Sum).Sum / 1GB

Write-Host "`nMEMORY INFORMATION"
Write-Host "------------------"
Write-Host "Total Installed RAM: $([math]::Round($TotalRAM, 2)) GB"

# OS
Write-Host "`nOPERATING SYSTEM"
Write-Host "----------------"

Write-Host "OS Name:           $($OS.Caption)"
Write-Host "Version:           $($OS.Version)"
Write-Host "Architecture:      $($OS.OSArchitecture)"
Write-Host "Hostname:          $($CS.Name)"

# Usernames
Write-Host "`nUSERNAMES"
Write-Host "---------"

Get-LocalUser | Where-Object Enabled | ForEach-Object {
    Write-Host "  $($_.Name)"
}

# HDD / SSD
Write-Host "`nSTORAGE INFORMATION"
Write-Host "-------------------"

foreach ($Disk in $Disks) {
    $Size = [math]::Round($Disk.Size / 1GB, 2)

    Write-Host "Model: $($Disk.Model)"
    Write-Host "Size: $Size GB"
}

Write-Host "`n==============================================="
Write-Host "               END OF REPORT"
Write-Host "==============================================="
