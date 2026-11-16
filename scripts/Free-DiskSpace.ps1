<#
.SYNOPSIS
    Shows what is using the system drive and runs the deeper Windows cleanups
    that free the most space.

.DESCRIPTION
    With no switches it only REPORTS (nothing is deleted):
      - free space, hibernation/page file sizes
      - known reclaimable folders (Windows.old, update downloads, dumps...)
      - the largest folders on the drive and inside user profiles
      - the largest files in user profiles

    Cleanup switches:
      -Caches              Run Clear-Caches.ps1 -All (must be in the same folder)
      -DiskCleanup         Windows Disk Cleanup, all categories except Downloads
                           and Recycle Bin. Removes Windows.old, old update
                           files, setup leftovers, etc.
      -ComponentCleanup    DISM clean-up of superseded Windows Update components
      -ResetBase           With -ComponentCleanup: frees more, but installed
                           updates can no longer be uninstalled
      -DisableHibernation  Turns hibernation off and deletes hiberfil.sys.
                           Hibernate and Fast Startup stop working.
      -Clean               = -Caches -DiskCleanup -ComponentCleanup

    Run as Administrator.

.PARAMETER Top
    How many rows to show in each "largest" list. Default 15.

.PARAMETER LargeFileMB
    Minimum size for the largest-files list. Default 500 MB.

.EXAMPLE
    .\Free-DiskSpace.ps1                 # report only
.EXAMPLE
    .\Free-DiskSpace.ps1 -Clean          # standard deep clean
.EXAMPLE
    .\Free-DiskSpace.ps1 -Clean -DisableHibernation
#>
[CmdletBinding()]
param(
    [switch]$Caches,
    [switch]$DiskCleanup,
    [switch]$ComponentCleanup,
    [switch]$ResetBase,
    [switch]$DisableHibernation,
    [switch]$Clean,
    [ValidateRange(5, 100)][int]$Top = 15,
    [ValidateRange(50, 100000)][int]$LargeFileMB = 500
)

$ErrorActionPreference = 'Stop'
if ($Clean) { $Caches = $true; $DiskCleanup = $true; $ComponentCleanup = $true }
$doCleanup = $Caches -or $DiskCleanup -or $ComponentCleanup -or $DisableHibernation

$drive = $env:SystemDrive            # e.g. C:
$root  = "$drive\"
$win   = $env:SystemRoot

# --------------------------------------------------------------------------
# Fast folder scanner (skips junctions/links and cloud-only placeholder files)
# --------------------------------------------------------------------------
if (-not ('DiskScan.Scanner' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;

namespace DiskScan
{
    public class BigFile
    {
        public long Bytes;
        public string Path;
    }

    public static class Scanner
    {
        const FileAttributes CloudOnly = FileAttributes.Offline | (FileAttributes)0x400000;

        // Total size of a folder. Files at least minBytes are added to 'big' when it is not null.
        public static long Scan(string path, long minBytes, List<BigFile> big)
        {
            long total = 0;
            Stack<string> stack = new Stack<string>();
            stack.Push(path);
            while (stack.Count > 0)
            {
                DirectoryInfo dir;
                try { dir = new DirectoryInfo(stack.Pop()); } catch { continue; }

                try
                {
                    foreach (FileInfo f in dir.EnumerateFiles())
                    {
                        try
                        {
                            if ((f.Attributes & FileAttributes.ReparsePoint) != 0 &&
                                (f.Attributes & CloudOnly) == 0) continue;
                            if ((f.Attributes & CloudOnly) != 0) continue;   // not stored on this disk
                            long len = f.Length;
                            total += len;
                            if (big != null && len >= minBytes)
                                big.Add(new BigFile { Bytes = len, Path = f.FullName });
                        }
                        catch { }
                    }
                }
                catch { }

                try
                {
                    foreach (DirectoryInfo d in dir.EnumerateDirectories())
                    {
                        try
                        {
                            if ((d.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                            stack.Push(d.FullName);
                        }
                        catch { }
                    }
                }
                catch { }
            }
            return total;
        }

        public static long Size(string path) { return Scan(path, 0, null); }
    }
}
'@
}

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-FreeGB {
    $d = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$drive'"
    [pscustomobject]@{
        FreeGB  = [math]::Round($d.FreeSpace / 1GB, 1)
        TotalGB = [math]::Round($d.Size / 1GB, 1)
    }
}

function Format-GB([long]$Bytes) { '{0,8:N2}' -f ($Bytes / 1GB) }

function Write-Title([string]$Text) {
    Write-Host ''
    Write-Host $Text -ForegroundColor Cyan
    Write-Host ('-' * $Text.Length) -ForegroundColor Cyan
}

function Get-ChildFolderSizes([string]$Parent) {
    $out = @()
    foreach ($d in @(Get-ChildItem -LiteralPath $Parent -Directory -Force -ErrorAction SilentlyContinue)) {
        if ($d.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        Write-Progress -Activity 'Measuring folders' -Status $d.FullName
        $out += [pscustomobject]@{ Path = $d.FullName; Bytes = [DiskScan.Scanner]::Size($d.FullName) }
    }
    Write-Progress -Activity 'Measuring folders' -Completed
    $out
}

function Show-Sizes($Rows, [int]$Count) {
    $Rows | Where-Object { $_.Bytes -gt 0 } | Sort-Object Bytes -Descending | Select-Object -First $Count |
        ForEach-Object { Write-Host ("{0} GB  {1}" -f (Format-GB $_.Bytes), $_.Path) }
}

function Get-UserProfileDirs {
    $dirs = @()
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    foreach ($k in @(Get-ChildItem -LiteralPath $key -ErrorAction SilentlyContinue)) {
        if ($k.PSChildName -notlike 'S-1-5-21-*') { continue }
        $p = (Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).ProfileImagePath
        if ($p) {
            $p = [Environment]::ExpandEnvironmentVariables($p)
            if (Test-Path -LiteralPath $p -PathType Container) { $dirs += $p }
        }
    }
    if ($dirs.Count -eq 0) { $dirs = @($env:USERPROFILE) }
    $dirs
}

# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------
function Show-Report {
    $f = Get-FreeGB
    Write-Title "Drive $drive"
    Write-Host ("{0} GB free of {1} GB ({2:N0}% free)" -f $f.FreeGB, $f.TotalGB, (100 * $f.FreeGB / $f.TotalGB))

    Write-Title 'System files'
    foreach ($name in 'hiberfil.sys', 'pagefile.sys', 'swapfile.sys') {
        try {
            $item = Get-Item -LiteralPath (Join-Path $root $name) -Force -ErrorAction Stop
            $hint = if ($name -eq 'hiberfil.sys') { '  <- removed by -DisableHibernation' } else { '' }
            Write-Host ("{0} GB  {1}{2}" -f (Format-GB $item.Length), $item.FullName, $hint)
        } catch { }
    }

    Write-Title 'Known reclaimable locations'
    $known = @(
        @{ Path = Join-Path $root 'Windows.old';                       Note = 'previous Windows (-DiskCleanup)' },
        @{ Path = Join-Path $root '$Windows.~BT';                      Note = 'upgrade leftovers (-DiskCleanup)' },
        @{ Path = Join-Path $root '$Windows.~WS';                      Note = 'upgrade leftovers (-DiskCleanup)' },
        @{ Path = Join-Path $win 'SoftwareDistribution\Download';      Note = 'update downloads (-Caches)' },
        @{ Path = Join-Path $win 'Temp';                               Note = 'Windows temp (-Caches)' },
        @{ Path = Join-Path $win 'Logs';                               Note = 'Windows logs (-DiskCleanup)' },
        @{ Path = Join-Path $win 'LiveKernelReports';                  Note = 'kernel dumps (-DiskCleanup)' },
        @{ Path = Join-Path $win 'Minidump';                           Note = 'crash dumps (-DiskCleanup)' },
        @{ Path = Join-Path $win 'Installer';                          Note = 'DO NOT delete by hand - needed for app repair/uninstall' }
    )
    foreach ($k in $known) {
        if (Test-Path -LiteralPath $k.Path -PathType Container) {
            $bytes = [DiskScan.Scanner]::Size($k.Path)
            if ($bytes -gt 50MB) { Write-Host ("{0} GB  {1}  ({2})" -f (Format-GB $bytes), $k.Path, $k.Note) }
        }
    }
    $dump = Join-Path $win 'MEMORY.DMP'
    if (Test-Path -LiteralPath $dump) {
        Write-Host ("{0} GB  {1}  (crash dump, -DiskCleanup)" -f (Format-GB (Get-Item -LiteralPath $dump -Force).Length), $dump)
    }

    Write-Title "Largest folders on $drive"
    Show-Sizes (Get-ChildFolderSizes $root) $Top

    Write-Title 'Largest folders inside user profiles'
    $rows = @()
    $big  = New-Object 'System.Collections.Generic.List[DiskScan.BigFile]'
    foreach ($p in Get-UserProfileDirs) {
        foreach ($d in @(Get-ChildItem -LiteralPath $p -Directory -Force -ErrorAction SilentlyContinue)) {
            if ($d.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            Write-Progress -Activity 'Measuring user folders' -Status $d.FullName
            if ($d.Name -eq 'AppData') {
                # Break AppData down one more level so the real culprit is visible.
                foreach ($sub in 'Local', 'LocalLow', 'Roaming') {
                    $subPath = Join-Path $d.FullName $sub
                    foreach ($a in @(Get-ChildItem -LiteralPath $subPath -Directory -Force -ErrorAction SilentlyContinue)) {
                        if ($a.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
                        $rows += [pscustomobject]@{ Path = $a.FullName; Bytes = [DiskScan.Scanner]::Scan($a.FullName, $LargeFileMB * 1MB, $big) }
                    }
                }
            } else {
                $rows += [pscustomobject]@{ Path = $d.FullName; Bytes = [DiskScan.Scanner]::Scan($d.FullName, $LargeFileMB * 1MB, $big) }
            }
        }
    }
    Write-Progress -Activity 'Measuring user folders' -Completed
    Show-Sizes $rows $Top

    Write-Title "Largest files in user profiles (over $LargeFileMB MB)"
    if ($big.Count -eq 0) {
        Write-Host 'None found.'
    } else {
        $big | Sort-Object Bytes -Descending | Select-Object -First $Top |
            ForEach-Object { Write-Host ("{0} GB  {1}" -f (Format-GB $_.Bytes), $_.Path) }
    }
    Write-Host ''
}

# --------------------------------------------------------------------------
# Cleanup actions
# --------------------------------------------------------------------------
function Invoke-CacheScript {
    $sibling = Join-Path $PSScriptRoot 'Clear-Caches.ps1'
    if (-not (Test-Path -LiteralPath $sibling)) {
        Write-Warning "Clear-Caches.ps1 was not found next to this script - skipping -Caches."
        return
    }
    Write-Title 'Clearing caches (Clear-Caches.ps1 -All)'
    & $sibling -All
}

function Invoke-DiskCleanup {
    Write-Title 'Windows Disk Cleanup'
    $slot    = 'StateFlags0099'
    $exclude = @('DownloadsFolder', 'Recycle Bin')      # never touch personal files
    $key     = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    $handlers = @(Get-ChildItem -LiteralPath $key -ErrorAction SilentlyContinue)
    if ($handlers.Count -eq 0) { Write-Warning 'Disk Cleanup handlers not found - skipping.'; return }

    try {
        foreach ($h in $handlers) {
            if ($exclude -contains $h.PSChildName) {
                Remove-ItemProperty -LiteralPath $h.PSPath -Name $slot -ErrorAction SilentlyContinue
            } else {
                Set-ItemProperty -LiteralPath $h.PSPath -Name $slot -Value 2 -Type DWord -ErrorAction SilentlyContinue
            }
        }
        Write-Host 'Running cleanmgr (a progress window may appear; this can take several minutes)...'
        Start-Process -FilePath (Join-Path $win 'System32\cleanmgr.exe') -ArgumentList '/sagerun:99' -Wait
        Write-Host 'Disk Cleanup finished.' -ForegroundColor Green
    } finally {
        foreach ($h in $handlers) {
            Remove-ItemProperty -LiteralPath $h.PSPath -Name $slot -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-ComponentCleanup {
    Write-Title 'Windows component store cleanup (DISM)'
    $dismArgs = @('/Online', '/Cleanup-Image', '/StartComponentCleanup')
    if ($ResetBase) {
        $dismArgs += '/ResetBase'
        Write-Warning 'ResetBase: installed Windows updates can no longer be uninstalled afterwards.'
    }
    Write-Host 'This can take 5-20 minutes...'
    & (Join-Path $win 'System32\Dism.exe') @dismArgs
    if ($LASTEXITCODE -eq 0) { Write-Host 'Component cleanup finished.' -ForegroundColor Green }
    else { Write-Warning "DISM exited with code $LASTEXITCODE (a pending restart is the usual cause)." }
}

function Disable-Hibernation {
    Write-Title 'Hibernation'
    & (Join-Path $win 'System32\powercfg.exe') /hibernate off
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Hibernation turned off and hiberfil.sys removed. Undo with: powercfg /hibernate on' -ForegroundColor Green
    } else {
        Write-Warning "powercfg exited with code $LASTEXITCODE."
    }
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
$IsAdmin = Test-Admin

if (-not $doCleanup) {
    if (-not $IsAdmin) { Write-Warning 'Not running as Administrator: some folders cannot be measured, so sizes may be too low.' }
    Show-Report
    Write-Host 'Report only - nothing was deleted. Add -Clean to run the standard cleanups.' -ForegroundColor Yellow
    return
}

if (-not $IsAdmin) { throw 'Cleanup needs an Administrator PowerShell window.' }
if ($ResetBase -and -not $ComponentCleanup) { Write-Warning '-ResetBase has no effect without -ComponentCleanup.' }

$before = Get-FreeGB
Write-Host ("Free before: {0} GB of {1} GB" -f $before.FreeGB, $before.TotalGB) -ForegroundColor Cyan

if ($Caches)             { try { Invoke-CacheScript }      catch { Write-Warning "Cache cleanup failed: $_" } }
if ($DiskCleanup)        { try { Invoke-DiskCleanup }      catch { Write-Warning "Disk Cleanup failed: $_" } }
if ($ComponentCleanup)   { try { Invoke-ComponentCleanup } catch { Write-Warning "Component cleanup failed: $_" } }
if ($DisableHibernation) { try { Disable-Hibernation }     catch { Write-Warning "Hibernation change failed: $_" } }

$after = Get-FreeGB
Write-Host ''
Write-Host ("Free before: {0} GB   Free after: {1} GB   Recovered: {2:N1} GB" -f `
    $before.FreeGB, $after.FreeGB, ($after.FreeGB - $before.FreeGB)) -ForegroundColor Green