<#
.SYNOPSIS
    Enhanced System Information Report - PowerShell Version
.DESCRIPTION
    Collects comprehensive system, hardware, user, and software information.
#>

Write-Host "==============================================="
Write-Host "           SYSTEM INFORMATION REPORT"
Write-Host "==============================================="
Write-Host "Generated on: $(Get-Date)"
Write-Host ""

# ======================
# 1. VENDOR & MODEL INFO
# ======================
Write-Host "🔹 VENDOR & MODEL INFORMATION"
Write-Host "----------------------------"

$ComputerSystem = Get-CimInstance Win32_ComputerSystem
$Bios = Get-CimInstance Win32_BIOS
$BaseBoard = Get-CimInstance Win32_BaseBoard
$Chassis = Get-CimInstance Win32_SystemEnclosure

Write-Host "System Vendor:      $($ComputerSystem.Manufacturer)"
Write-Host "Device Model:       $($ComputerSystem.Model)"
Write-Host "System Family:      $($ComputerSystem.SystemFamily)"
Write-Host "Board Vendor:       $($BaseBoard.Manufacturer)"
Write-Host "BIOS Vendor:        $($Bios.Manufacturer)"
Write-Host "BIOS Version:       $($Bios.SMBIOSBIOSVersion)"
Write-Host "BIOS Release Date:  $($Bios.ReleaseDate)"
Write-Host "Chassis Vendor:     $($Chassis.Manufacturer)"
Write-Host "Chassis Type:       $($Chassis.ChassisTypes -join ', ')"

# ======================
# 2. SERIAL NUMBERS
# ======================
Write-Host ""
Write-Host "🔹 SERIAL NUMBERS"
Write-Host "-----------------"

Write-Host "System Serial:      $($ComputerSystem.IdentifyingNumber)"
Write-Host "Board Serial:       $($BaseBoard.SerialNumber)"
Write-Host "Chassis Serial:     $($Chassis.SerialNumber)"

# Disk Serial Numbers
Write-Host ""
Write-Host "💾 DISK SERIAL NUMBERS"
Get-CimInstance Win32_DiskDrive | ForEach-Object {
    Write-Host "  Name: $($_.DeviceID)"
    Write-Host "    Model: $($_.Model)"
    Write-Host "    Serial: $($_.SerialNumber)"
    Write-Host "    Size: $([math]::Round($_.Size / 1GB, 2)) GB"
}

# ======================
# 3. HARDWARE INFO
# ======================
Write-Host ""
Write-Host "🔹 HARDWARE INFORMATION"
Write-Host "-----------------------"

# CPU
Write-Host "💻 CPU DETAILS"
$CPU = Get-CimInstance Win32_Processor
Write-Host "  Name: $($CPU.Name)"
Write-Host "  Cores: $($CPU.NumberOfCores)"
Write-Host "  Logical Processors: $($CPU.NumberOfLogicalProcessors)"
Write-Host "  Max Clock Speed: $($CPU.MaxClockSpeed) MHz"
Write-Host "  Manufacturer: $($CPU.Manufacturer)"

# Memory
Write-Host ""
Write-Host "🧠 MEMORY DETAILS"
$Memory = Get-CimInstance Win32_PhysicalMemory
$totalMemory = ($Memory | Measure-Object -Property Capacity -Sum).Sum / 1GB
Write-Host "Total Installed RAM: $([math]::Round($totalMemory,2)) GB"
$Memory | ForEach-Object {
    Write-Host "  BankLabel: $($_.BankLabel), Size: $([math]::Round($_.Capacity/1GB,2)) GB, Speed: $($_.Speed) MHz, Type: $($_.MemoryType)"
}

# GPU
Write-Host ""
Write-Host "🎮 GPU DETAILS"
Get-CimInstance Win32_VideoController | ForEach-Object {
    Write-Host "  Name: $($_.Name), DriverVersion: $($_.DriverVersion), AdapterRAM: $([math]::Round($_.AdapterRAM/1MB)) MB"
}

# Network Interfaces
Write-Host ""
Write-Host "🌐 NETWORK INTERFACES"
Get-NetAdapter | ForEach-Object {
    Write-Host "  Name: $($_.Name), Status: $($_.Status), MAC: $($_.MacAddress), LinkSpeed: $($_.LinkSpeed)"
}

# USB Devices
Write-Host ""
Write-Host "🔌 USB DEVICES"
Get-CimInstance Win32_USBHub | ForEach-Object {
    Write-Host "  Device: $($_.Name), PNPDeviceID: $($_.PNPDeviceID)"
}

# ======================
# 4. OPERATING SYSTEM INFO
# ======================
Write-Host ""
Write-Host "🔹 OPERATING SYSTEM INFORMATION"
Write-Host "-------------------------------"
$OS = Get-CimInstance Win32_OperatingSystem
Write-Host "OS Name:           $($OS.Caption)"
Write-Host "Version:           $($OS.Version)"
Write-Host "BuildNumber:       $($OS.BuildNumber)"
Write-Host "Architecture:      $($OS.OSArchitecture)"
Write-Host "Hostname:          $($OS.CSName)"
Write-Host "Uptime:            $((Get-Date) - ($OS.LastBootUpTime))"

# ======================
# 5. SYSTEM HEALTH
# ======================
Write-Host ""
Write-Host "🔹 SYSTEM HEALTH"
Write-Host "----------------"

# CPU Load
$cpuLoad = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
Write-Host "CPU Load:          $cpuLoad %"

# Battery (if available)
Write-Host "Battery Status:"
Get-CimInstance Win32_Battery | ForEach-Object {
    Write-Host "  Name: $($_.Name), Status: $($_.BatteryStatus), Charge: $($_.EstimatedChargeRemaining)%"
}

# ======================
# 6. INSTALLED SOFTWARE
# ======================
Write-Host ""
Write-Host "📦 INSTALLED SOFTWARE (User-installed)"
Write-Host "-----------------------------------------"
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName, DisplayVersion, Publisher |
    Sort-Object DisplayName | ForEach-Object {
        if ($_.DisplayName) {
            Write-Host "  $($_.DisplayName) - $($_.DisplayVersion) - $($_.Publisher)"
        }
    }

# ======================
# 7. LOCAL USERS & PERMISSIONS
# ======================
Write-Host ""
Write-Host "👤 LOCAL USERS & PERMISSIONS"
Write-Host "-----------------------------"

$localUsers = Get-LocalUser | Where-Object { $_.Enabled -eq $true }

foreach ($user in $localUsers) {

    Write-Host ""
    Write-Host "User: $($user.Name)"
    Write-Host "  Enabled: $($user.Enabled)"
    Write-Host "  Password Required: $($user.PasswordRequired)"

    # Group Memberships (Primary permission source)
    $userGroups = Get-LocalGroup | ForEach-Object {
        try {
            if (Get-LocalGroupMember $_.Name -Member $user.Name -ErrorAction Stop) {
                $_.Name
            }
        } catch {}
    }

    if ($userGroups) {
        Write-Host "  Groups: $($userGroups -join ', ')"
    } else {
        Write-Host "  Groups: None"
    }

    # Home Directory Permissions
    $homeDir = "C:\Users\$($user.Name)"
    if (Test-Path $homeDir) {
        Write-Host "  Home Directory: $homeDir"
        Write-Host "  NTFS Permissions:"
        (Get-Acl $homeDir).Access | ForEach-Object {
            Write-Host "    $($_.IdentityReference) : $($_.FileSystemRights) [$($_.AccessControlType)]"
        }
    } else {
        Write-Host "  Home Directory: Not Found"
    }
}

Write-Host ""
Write-Host "==============================================="
Write-Host "           END OF REPORT"
Write-Host "==============================================="
