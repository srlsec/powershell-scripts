# System Information Collector - Complete Profile
Write-Host "`n" + "="*50
Write-Host "SYSTEM INFORMATION REPORT"
Write-Host "="*50 + "`n"

# Function to get formatted date
function Get-FormattedDate {
    return Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

Write-Host "Report Generated: $(Get-FormattedDate)`n"

# Initialize variables to avoid null reference errors
$computerSystem = $null
$csProduct = $null
$osInfo = $null
$biosInfo = $null
$processor = $null
$baseboard = $null

# 1. Model Information
Write-Host "1. MODEL INFORMATION" -ForegroundColor Cyan
Write-Host "-"*25
try {
    $computerSystem = Get-CimInstance Win32_ComputerSystem
    $csProduct = Get-CimInstance Win32_ComputerSystemProduct
    
    Write-Host "Model:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t`t$($computerSystem.Model)" -ForegroundColor White
    
    Write-Host "System SKU:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$($csProduct.Version)" -ForegroundColor White
    
    Write-Host "Manufacturer:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$($computerSystem.Manufacturer)" -ForegroundColor White
    
    # Get product name/SKU if available
    $systemSKU = (Get-CimInstance Win32_ComputerSystem).SystemSKUNumber
    if ($systemSKU) {
        Write-Host "Product SKU:" -ForegroundColor Yellow -NoNewline
        Write-Host "`t`t$systemSKU" -ForegroundColor White
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# 2. Operating System Information
Write-Host "`n2. OPERATING SYSTEM" -ForegroundColor Cyan
Write-Host "-"*25
try {
    $osInfo = Get-CimInstance Win32_OperatingSystem
    
    # Extract Windows version name
    $windowsName = switch -Wildcard ($osInfo.Caption) {
        "*Windows 11*" { "Windows 11" }
        "*Windows 10*" { "Windows 10" }
        "*Windows 8*" { "Windows 8" }
        "*Windows 7*" { "Windows 7" }
        default { $osInfo.Caption }
    }
    
    Write-Host "Operating System:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t$windowsName" -ForegroundColor White
    
    Write-Host "OS Version:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$($osInfo.Version)" -ForegroundColor White
    
    Write-Host "Build Number:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$($osInfo.BuildNumber)" -ForegroundColor White
    
    Write-Host "Architecture:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$($osInfo.OSArchitecture)" -ForegroundColor White
    
    Write-Host "Install Date:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$(($osInfo.InstallDate).ToString('yyyy-MM-dd'))" -ForegroundColor White
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# 3. Serial Number
Write-Host "`n3. SERIAL NUMBER" -ForegroundColor Cyan
Write-Host "-"*25
try {
    $biosInfo = Get-CimInstance Win32_BIOS
    $csProduct = Get-CimInstance Win32_ComputerSystemProduct
    
    Write-Host "BIOS Serial:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$($biosInfo.SerialNumber)" -ForegroundColor White
    
    Write-Host "System Serial:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$($csProduct.IdentifyingNumber)" -ForegroundColor White
    
    # Check if serials match
    if ($biosInfo.SerialNumber -ne $csProduct.IdentifyingNumber) {
        Write-Host "Note: Serial numbers differ (common for some manufacturers)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# 4. Processor Information
Write-Host "`n4. PROCESSOR" -ForegroundColor Cyan
Write-Host "-"*25
try {
    $processor = Get-CimInstance Win32_Processor
    
    # Extract processor generation (for Intel)
    $procName = $processor.Name.Trim()
    $generation = "Unknown"
    
    if ($procName -match "i[0-9]-[0-9]{4}") {
        # Intel Core iX-XXXX pattern
        $genMatch = [regex]::Match($procName, 'i[0-9]-([0-9]{4})')
        if ($genMatch.Success) {
            $firstDigit = $genMatch.Groups[1].Value.Substring(0,1)
            $generation = "Gen $firstDigit"
        }
    } elseif ($procName -match "(Ryzen|Athlon|Threadripper)") {
        # AMD processors
        if ($procName -match "Ryzen ([0-9])") {
            $generation = "Ryzen Gen $($matches[1])"
        }
    }
    
    Write-Host "Processor:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$procName" -ForegroundColor White
    
    Write-Host "Generation:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$generation" -ForegroundColor White
    
    Write-Host "Cores/Threads:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$($processor.NumberOfCores)/$($processor.NumberOfLogicalProcessors)" -ForegroundColor White
    
    Write-Host "Clock Speed:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$($processor.MaxClockSpeed) MHz" -ForegroundColor White
    
    Write-Host "Current Speed:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t$($processor.CurrentClockSpeed) MHz" -ForegroundColor White
    
    Write-Host "Manufacturer:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$($processor.Manufacturer)" -ForegroundColor White
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# 5. RAM Information
Write-Host "`n5. MEMORY (RAM)" -ForegroundColor Cyan
Write-Host "-"*25
try {
    $totalMemory = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    $memorySlots = Get-CimInstance Win32_PhysicalMemory
    
    Write-Host "Total RAM:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$totalMemory GB" -ForegroundColor White
    
    if ($memorySlots) {
        Write-Host "`nMemory Configuration:" -ForegroundColor Yellow
        
        $slotCount = 0
        $totalCapacity = 0
        
        foreach ($mem in $memorySlots) {
            $slotCount++
            $sizeGB = [math]::Round($mem.Capacity / 1GB, 2)
            $totalCapacity += $sizeGB
            
            # FIXED: Using $() to wrap the variable
            Write-Host "  Slot $($slotCount):" -ForegroundColor Yellow -NoNewline
            Write-Host " $sizeGB GB @ $($mem.Speed) MHz" -ForegroundColor White
            
            if ($mem.PartNumber -and $mem.PartNumber.Trim() -ne "") {
                Write-Host "    Part: $($mem.PartNumber.Trim())" -ForegroundColor Gray
            }
        }
        
        # Check if reported total matches sum of slots
        if ([math]::Abs($totalCapacity - $totalMemory) -gt 0.1) {
            Write-Host "Note: Memory total may include shared GPU memory" -ForegroundColor Gray
        }
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# 6. Storage Information
Write-Host "`n6. STORAGE" -ForegroundColor Cyan
Write-Host "-"*25
try {
    $disks = Get-CimInstance Win32_DiskDrive | Where-Object {$_.MediaType -like "*Fixed*" -or $_.MediaType -like "*SSD*" -or $_.MediaType -eq $null}
    $totalStorage = 0
    
    if ($disks) {
        $diskCount = 0
        foreach ($disk in $disks) {
            $diskCount++
            $sizeGB = [math]::Round($disk.Size / 1GB, 2)
            $totalStorage += $sizeGB
            
            $diskType = if ($disk.Model -like "*SSD*" -or $disk.MediaType -like "*SSD*") { "SSD" }
                        elseif ($disk.Model -like "*HDD*" -or $disk.MediaType -like "*HDD*") { "HDD" }
                        elseif ($disk.Model -like "*NVMe*") { "NVMe SSD" }
                        else { "Unknown" }
            
            # FIXED: Using $() to wrap the variable
            Write-Host "Disk $($diskCount):" -ForegroundColor Yellow -NoNewline
            Write-Host "`t$sizeGB GB $diskType" -ForegroundColor White
            
            Write-Host "  Model:" -ForegroundColor Yellow -NoNewline
            Write-Host "`t$($disk.Model.Trim())" -ForegroundColor Gray
            
            if ($disk.SerialNumber -and $disk.SerialNumber.Trim() -ne "") {
                Write-Host "  Serial:" -ForegroundColor Yellow -NoNewline
                Write-Host "`t$($disk.SerialNumber.Trim())" -ForegroundColor Gray
            }
        }
        
        Write-Host "`nTotal Storage:" -ForegroundColor Yellow -NoNewline
        Write-Host "`t$totalStorage GB" -ForegroundColor White
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# 7. Motherboard Information
Write-Host "`n7. MOTHERBOARD" -ForegroundColor Cyan
Write-Host "-"*25
try {
    $baseboard = Get-CimInstance Win32_BaseBoard
    
    Write-Host "Product:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$($baseboard.Product)" -ForegroundColor White
    
    Write-Host "Manufacturer:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$($baseboard.Manufacturer)" -ForegroundColor White
    
    Write-Host "Version:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t`t$($baseboard.Version)" -ForegroundColor White
    
    if ($baseboard.SerialNumber -and $baseboard.SerialNumber.Trim() -ne "") {
        Write-Host "Serial:" -ForegroundColor Yellow -NoNewline
        Write-Host "`t`t$($baseboard.SerialNumber.Trim())" -ForegroundColor White
    }
    
    # Get BIOS information too
    $bios = Get-CimInstance Win32_BIOS
    Write-Host "BIOS Version:" -ForegroundColor Yellow -NoNewline
    Write-Host "`t$($bios.SMBIOSBIOSVersion)" -ForegroundColor White
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

# Summary
Write-Host "`n" + "="*50
Write-Host "SUMMARY"
Write-Host "="*50

$summary = @{}
if ($computerSystem) { $summary["Model"] = $computerSystem.Model }
if ($csProduct) { $summary["System SKU"] = $csProduct.Version }
if ($computerSystem) { $summary["Manufacturer"] = $computerSystem.Manufacturer }
if ($biosInfo) { $summary["Serial"] = $biosInfo.SerialNumber }
if ($processor -and $procName) { $summary["Processor"] = "$procName ($generation)" }
if ($processor) { $summary["Cores/Threads"] = "$($processor.NumberOfCores)/$($processor.NumberOfLogicalProcessors)" }
if ($totalMemory) { $summary["RAM"] = "$totalMemory GB" }
if ($totalStorage) { $summary["Storage"] = "$totalStorage GB" }
if ($windowsName -and $osInfo) { $summary["OS"] = "$windowsName $($osInfo.Version)" }

$summary.GetEnumerator() | ForEach-Object {
    Write-Host "$($_.Key):" -ForegroundColor Cyan -NoNewline
    Write-Host "`t$($_.Value)" -ForegroundColor White
}

Write-Host "`n" + "="*50
Write-Host "END OF REPORT"
Write-Host "="*50