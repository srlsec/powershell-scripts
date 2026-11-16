<#
.SYNOPSIS
    Clears Windows cache and temporary files and reports the disk space freed.

.DESCRIPTION
    Always cleaned:
      - The Temp folder of every user on the PC
          (C:\Users\<each user>\AppData\Local\Temp), found automatically
      - Windows Temp and Windows Prefetch (C:\Windows\Temp, C:\Windows\Prefetch)
      - Any extra folders given in -Paths
      - DNS resolver cache
      - Thumbnail and icon caches
      - Internet cache (INetCache)
      - DirectX shader cache
      - Windows Error Reporting files and app crash dumps
      - Delivery Optimization cache

    Opt-in switches:
      -Browsers        Chrome, Edge, Brave and Firefox caches (not cookies,
                       history or passwords). A browser that is open is skipped.
      -WindowsUpdate   Downloaded update files (SoftwareDistribution\Download)
      -RecycleBin      Empty the Recycle Bin on all drives
      -All             Everything above

    Run as Administrator: C:\Windows\Temp, C:\Windows\Prefetch and the other
    system-level items cannot be cleared without it.

    Works on any PC: no user name or drive letter is hard-coded.

.PARAMETER Paths
    Extra folders whose contents are deleted on every run. The folders
    themselves are kept. Drive roots and system folders are refused.

.PARAMETER CurrentUserOnly
    Clear only the Temp folder of the account running the script instead of
    every user's Temp folder.

.PARAMETER Preview
    Show what would be deleted and how much space it would free; delete nothing.

.PARAMETER MinAgeHours
    Keep files newer than this in the Temp, Prefetch and -Paths folders. Default 0 = delete
    everything that is not locked. Use e.g. 24 to protect running installers.

.EXAMPLE
    .\Clear-Caches.ps1 -Preview -All
.EXAMPLE
    .\Clear-Caches.ps1 -Browsers -RecycleBin
.EXAMPLE
    .\Clear-Caches.ps1 -Paths 'D:\Scratch','E:\Build\Temp'
#>
[CmdletBinding()]
param(
    [string[]]$Paths = @(),
    [switch]$CurrentUserOnly,
    [switch]$Browsers,
    [switch]$WindowsUpdate,
    [switch]$RecycleBin,
    [switch]$All,
    [switch]$Preview,
    [ValidateRange(0, 8760)][int]$MinAgeHours = 0
)

$ErrorActionPreference = 'Stop'
if ($All) { $Browsers = $true; $WindowsUpdate = $true; $RecycleBin = $true }

$script:Results = New-Object System.Collections.Generic.List[object]

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}
$IsAdmin = Test-Admin

function Add-Result([string]$Item, [long]$Files, [long]$Bytes, [string]$Note = '') {
    $script:Results.Add([pscustomobject]@{
        Item  = $Item
        Files = $Files
        MB    = [math]::Round($Bytes / 1MB, 1)
        Note  = $Note
    })
}

# Lists files under a folder without following junctions or symbolic links,
# so a link inside a cache folder can never lead the cleanup somewhere else.
function Get-TreeItems([string]$Root) {
    $files = New-Object System.Collections.Generic.List[object]
    $dirs  = New-Object System.Collections.Generic.List[object]
    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($Root)
    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        $children = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)
        foreach ($c in $children) {
            if ($c.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            if ($c.PSIsContainer) { $dirs.Add($c); $stack.Push($c.FullName) }
            else { $files.Add($c) }
        }
    }
    [pscustomobject]@{ Files = $files; Dirs = $dirs }
}

# Deletes files in a folder (optionally by name pattern / minimum age).
# Locked files are skipped silently.
function Clear-Folder {
    param(
        [string]$Label,
        [string]$Path,
        [string]$Pattern = '*',
        [int]$AgeHours = 0
    )
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Container)) { return }

    $tree   = Get-TreeItems $Path
    $cutoff = (Get-Date).AddHours(-$AgeHours)
    $count  = 0
    [long]$bytes = 0

    foreach ($f in $tree.Files) {
        if ($f.Name -notlike $Pattern) { continue }
        if ($AgeHours -gt 0 -and $f.LastWriteTime -gt $cutoff) { continue }
        $size = $f.Length
        if ($Preview) { $count++; $bytes += $size; continue }
        try {
            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
            $count++; $bytes += $size
        } catch { }   # in use or access denied: leave it
    }

    if (-not $Preview -and $Pattern -eq '*') {
        # Remove folders that are now empty, deepest first.
        foreach ($d in ($tree.Dirs | Sort-Object { $_.FullName.Length } -Descending)) {
            try {
                if (-not (Get-ChildItem -LiteralPath $d.FullName -Force -ErrorAction Stop | Select-Object -First 1)) {
                    Remove-Item -LiteralPath $d.FullName -Force -ErrorAction Stop
                }
            } catch { }
        }
    }
    Add-Result $Label $count $bytes
}

function Test-Running([string[]]$Names) {
    [bool](Get-Process -Name $Names -ErrorAction SilentlyContinue)
}

# --------------------------------------------------------------------------
Write-Host ''
if ($Preview) { Write-Host 'PREVIEW - nothing will be deleted.' -ForegroundColor Yellow }
if (-not $IsAdmin) { Write-Warning 'Not running as Administrator: system-level caches are skipped.' }

$local = $env:LOCALAPPDATA
$win   = $env:SystemRoot

# --- Listed folders: clear all contents -------------------------------------
# Never accept a drive root or a core system folder as a target.
$protected = @($env:SystemRoot, $env:SystemDrive, $env:USERPROFILE, $env:ProgramFiles,
               ${env:ProgramFiles(x86)}, $env:ProgramData, $env:LOCALAPPDATA, $env:APPDATA,
               (Join-Path $env:SystemRoot 'System32'), (Join-Path $env:SystemDrive 'Users')) |
    Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }

$targets = New-Object System.Collections.Generic.List[string]
# Temp folder of every real user profile on this PC (from the registry, so it
# also works when profiles are not under C:\Users). Needs admin for other users.
$userTemps = @($env:TEMP)
if (-not $CurrentUserOnly -and $IsAdmin) {
    $profileKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    foreach ($k in @(Get-ChildItem -LiteralPath $profileKey -ErrorAction SilentlyContinue)) {
        if ($k.PSChildName -notlike 'S-1-5-21-*') { continue }      # skip system/service accounts
        $profileDir = (Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).ProfileImagePath
        if ($profileDir) { $userTemps += (Join-Path ([Environment]::ExpandEnvironmentVariables($profileDir)) 'AppData\Local\Temp') }
    }
}

$systemFolders = @((Join-Path $win 'Temp'), (Join-Path $win 'Prefetch'))

foreach ($t in ($userTemps + $systemFolders + @($Paths))) {
    if ([string]::IsNullOrWhiteSpace($t)) { continue }
    $full = [IO.Path]::GetFullPath($t).TrimEnd('\')
    if ($targets -notcontains $full) { $targets.Add($full) }   # -notcontains ignores case
}

foreach ($t in $targets) {
    $depth = ($t -split '\\' | Where-Object { $_ }).Count        # C:\Windows\Temp = 3
    if ($depth -lt 3 -or $protected -contains $t) {
        Add-Result $t 0 0 'refused - protected location'
    } elseif (-not (Test-Path -LiteralPath $t -PathType Container)) {
        if ($Paths -contains $t) { Add-Result $t 0 0 'not found' }   # report only folders the user asked for
    } else {
        Clear-Folder $t $t -AgeHours $MinAgeHours
    }
}

# --- DNS cache -------------------------------------------------------------
if ($Preview) {
    Add-Result 'DNS cache' 0 0 'would be flushed'
} else {
    try { Clear-DnsClientCache; Add-Result 'DNS cache' 0 0 'flushed' }
    catch { Add-Result 'DNS cache' 0 0 'failed' }
}

# --- Explorer thumbnail / icon caches (files in use are skipped) -----------
$explorer = Join-Path $local 'Microsoft\Windows\Explorer'
Clear-Folder 'Thumbnail cache' $explorer -Pattern 'thumbcache_*.db'
Clear-Folder 'Icon cache'      $explorer -Pattern 'iconcache_*.db'

# --- Other per-user caches -------------------------------------------------
Clear-Folder 'Internet cache'       (Join-Path $local 'Microsoft\Windows\INetCache')
Clear-Folder 'DirectX shader cache' (Join-Path $local 'D3DSCache')
Clear-Folder 'App crash dumps'      (Join-Path $local 'CrashDumps')
Clear-Folder 'Error reports (user)' (Join-Path $local 'Microsoft\Windows\WER')

# --- System-level caches ---------------------------------------------------
if ($IsAdmin) {
    $wer = Join-Path $env:ProgramData 'Microsoft\Windows\WER'
    Clear-Folder 'Error reports (system)' (Join-Path $wer 'ReportQueue')
    Clear-Folder 'Error reports (archive)' (Join-Path $wer 'ReportArchive')

    if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) {
        if ($Preview) {
            Add-Result 'Delivery Optimization' 0 0 'would be cleared'
        } else {
            try { Delete-DeliveryOptimizationCache -Force | Out-Null; Add-Result 'Delivery Optimization' 0 0 'cleared' }
            catch { Add-Result 'Delivery Optimization' 0 0 'failed' }
        }
    }
}

# --- Browsers --------------------------------------------------------------
if ($Browsers) {
    $chromium = @(
        @{ Name = 'Chrome'; Proc = 'chrome'; Root = Join-Path $local 'Google\Chrome\User Data' },
        @{ Name = 'Edge';   Proc = 'msedge'; Root = Join-Path $local 'Microsoft\Edge\User Data' },
        @{ Name = 'Brave';  Proc = 'brave';  Root = Join-Path $local 'BraveSoftware\Brave-Browser\User Data' }
    )
    foreach ($b in $chromium) {
        if (-not (Test-Path -LiteralPath $b.Root)) { continue }
        if (Test-Running $b.Proc) { Add-Result "$($b.Name) cache" 0 0 'skipped - browser is open'; continue }

        $profiles = @(Get-ChildItem -LiteralPath $b.Root -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' })
        $before = $script:Results.Count
        foreach ($p in $profiles) {
            foreach ($sub in 'Cache', 'Code Cache', 'GPUCache', 'Service Worker\CacheStorage') {
                Clear-Folder 'tmp' (Join-Path $p.FullName $sub)
            }
        }
        foreach ($sub in 'ShaderCache', 'GrShaderCache') { Clear-Folder 'tmp' (Join-Path $b.Root $sub) }

        # Roll the per-folder rows up into one row per browser.
        $rows = @($script:Results | Select-Object -Skip $before)
        while ($script:Results.Count -gt $before) { $script:Results.RemoveAt($script:Results.Count - 1) }
        $sumFiles = ($rows | Measure-Object Files -Sum).Sum
        $sumMB    = ($rows | Measure-Object MB -Sum).Sum
        Add-Result "$($b.Name) cache" ([long]$sumFiles) ([long]($sumMB * 1MB))
    }

    $ffRoot = Join-Path $local 'Mozilla\Firefox\Profiles'
    if (Test-Path -LiteralPath $ffRoot) {
        if (Test-Running 'firefox') {
            Add-Result 'Firefox cache' 0 0 'skipped - browser is open'
        } else {
            $before = $script:Results.Count
            foreach ($p in @(Get-ChildItem -LiteralPath $ffRoot -Directory -Force -ErrorAction SilentlyContinue)) {
                foreach ($sub in 'cache2', 'startupCache', 'thumbnails') {
                    Clear-Folder 'tmp' (Join-Path $p.FullName $sub)
                }
            }
            $rows = @($script:Results | Select-Object -Skip $before)
            while ($script:Results.Count -gt $before) { $script:Results.RemoveAt($script:Results.Count - 1) }
            $sumFiles = ($rows | Measure-Object Files -Sum).Sum
            $sumMB    = ($rows | Measure-Object MB -Sum).Sum
            Add-Result 'Firefox cache' ([long]$sumFiles) ([long]($sumMB * 1MB))
        }
    }
}

# --- Windows Update download cache ----------------------------------------
if ($WindowsUpdate) {
    $dl = Join-Path $win 'SoftwareDistribution\Download'
    if (-not $IsAdmin) {
        Add-Result 'Windows Update downloads' 0 0 'skipped - needs admin'
    } elseif ($Preview) {
        Clear-Folder 'Windows Update downloads' $dl
    } else {
        $services = @('wuauserv', 'bits', 'dosvc')
        $wasRunning = @(Get-Service -Name $services -ErrorAction SilentlyContinue |
            Where-Object { $_.Status -eq 'Running' } | ForEach-Object { $_.Name })
        try {
            foreach ($s in $wasRunning) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }
            Clear-Folder 'Windows Update downloads' $dl
        } finally {
            foreach ($s in $wasRunning) { Start-Service -Name $s -ErrorAction SilentlyContinue }
        }
    }
}

# --- Recycle Bin -----------------------------------------------------------
if ($RecycleBin) {
    if ($Preview) {
        Add-Result 'Recycle Bin' 0 0 'would be emptied'
    } else {
        try { Clear-RecycleBin -Force -ErrorAction Stop; Add-Result 'Recycle Bin' 0 0 'emptied' }
        catch { Add-Result 'Recycle Bin' 0 0 'already empty or failed' }
    }
}

# --- Summary ---------------------------------------------------------------
$script:Results | Format-Table Item, Files, MB, Note -AutoSize

$totalMB = ($script:Results | Measure-Object MB -Sum).Sum
$verb = if ($Preview) { 'Would free' } else { 'Freed' }
Write-Host ("{0} about {1:N1} MB (items without a size, such as the Recycle Bin, are not counted)." -f $verb, $totalMB) -ForegroundColor Green
Write-Host ''