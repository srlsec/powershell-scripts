<#
.SYNOPSIS
    Frees up as much RAM as Windows allows: trims all working sets, releases the
    system file cache and registry cache, merges duplicate pages, flushes the
    modified page list, purges both standby lists and (optionally) clears the
    clipboard.

.DESCRIPTION
    PowerShell equivalent of the main Wise Memory Optimizer functions.

      One-click optimize ......... .\Optimize-Memory.ps1
      Auto optimization .......... .\Optimize-Memory.ps1 -Monitor -ThresholdMB 2048
      Optimize every N minutes ... .\Optimize-Memory.ps1 -Monitor -IntervalMinutes 25
      Run when Windows starts .... .\Optimize-Memory.ps1 -Install -ThresholdMB 2048
      Remove from startup ........ .\Optimize-Memory.ps1 -Uninstall

    Run from an elevated (Administrator) PowerShell window. Without admin
    rights only your own processes are trimmed; every other step is skipped.

.PARAMETER Monitor
    Keep running and optimize automatically (see -ThresholdMB / -IntervalMinutes).

.PARAMETER ThresholdMB
    In monitor mode, optimize when available memory drops below this value.

.PARAMETER IntervalMinutes
    In monitor mode, optimize every N minutes regardless of available memory.

.PARAMETER IdleCpuPercent
    In monitor mode, only optimize when total CPU load is below this percentage.
    0 (default) disables the idle check.

.PARAMETER CheckSeconds
    How often monitor mode checks memory. Default 30 seconds.

.PARAMETER ClearClipboard
    Also clear the clipboard on each optimization.

.PARAMETER SkipStandby
    Leave the modified and standby (cache) lists alone; do everything else.

.PARAMETER Install
    Register a scheduled task that starts monitor mode at logon, elevated.

.PARAMETER Uninstall
    Remove that scheduled task.
#>
[CmdletBinding()]
param(
    [switch]$Monitor,
    [int]$ThresholdMB = 0,
    [int]$IntervalMinutes = 0,
    [ValidateRange(0, 100)][int]$IdleCpuPercent = 0,
    [ValidateRange(5, 3600)][int]$CheckSeconds = 30,
    [switch]$ClearClipboard,
    [switch]$SkipStandby,
    [switch]$Install,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$TaskName = 'PS Memory Optimizer'

# --------------------------------------------------------------------------
# Native API wrapper
# --------------------------------------------------------------------------
if (-not ('MemOptMax.Native' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace MemOptMax
{
    public static class Native
    {
        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        struct TokPriv1Luid
        {
            public int Count;
            public long Luid;
            public int Attr;
        }

        [DllImport("kernel32.dll")]
        static extern IntPtr GetCurrentProcess();

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr OpenProcess(uint access, bool inherit, int pid);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool CloseHandle(IntPtr handle);

        [DllImport("psapi.dll", SetLastError = true)]
        static extern bool EmptyWorkingSet(IntPtr process);

        [DllImport("advapi32.dll", SetLastError = true)]
        static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        static extern bool LookupPrivilegeValue(string host, string name, ref long luid);

        [DllImport("advapi32.dll", SetLastError = true)]
        static extern bool AdjustTokenPrivileges(IntPtr token, bool disableAll,
            ref TokPriv1Luid newState, int len, IntPtr prev, IntPtr retLen);

        [StructLayout(LayoutKind.Sequential)]
        struct MemoryCombineInformationEx
        {
            public IntPtr Handle;
            public UIntPtr PagesCombined;
            public uint Flags;
        }

        [DllImport("ntdll.dll")]
        static extern int NtSetSystemInformation(int infoClass, ref int info, int length);

        [DllImport("ntdll.dll")]
        static extern int NtSetSystemInformation(int infoClass, IntPtr info, int length);

        [DllImport("ntdll.dll")]
        static extern int NtSetSystemInformation(int infoClass, ref MemoryCombineInformationEx info, int length);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool SetSystemFileCacheSize(IntPtr min, IntPtr max, int flags);

        const int SystemMemoryListInformation = 80;
        const int SystemCombinePhysicalMemoryInformation = 130;
        const int SystemRegistryReconciliationInformation = 155;
        const int MemoryEmptyWorkingSets = 2;
        const int MemoryFlushModifiedList = 3;
        const int MemoryPurgeStandbyList = 4;
        const int MemoryPurgeLowPriorityStandbyList = 5;

        const uint TOKEN_ADJUST_PRIVILEGES = 0x20;
        const uint TOKEN_QUERY = 0x08;
        const int SE_PRIVILEGE_ENABLED = 2;
        const uint PROCESS_QUERY_INFORMATION = 0x0400;
        const uint PROCESS_SET_QUOTA = 0x0100;

        public static bool EnablePrivilege(string name)
        {
            IntPtr token;
            if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out token))
                return false;
            try
            {
                TokPriv1Luid tp = new TokPriv1Luid();
                tp.Count = 1;
                tp.Luid = 0;
                tp.Attr = SE_PRIVILEGE_ENABLED;
                if (!LookupPrivilegeValue(null, name, ref tp.Luid)) return false;
                if (!AdjustTokenPrivileges(token, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero)) return false;
                return Marshal.GetLastWin32Error() == 0;   // 1300 = privilege not held
            }
            finally { CloseHandle(token); }
        }

        // Trims the working set of every process we are allowed to open.
        // Returns the number of processes trimmed.
        public static int TrimAllWorkingSets()
        {
            int done = 0;
            foreach (Process p in Process.GetProcesses())
            {
                try
                {
                    IntPtr h = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_SET_QUOTA, false, p.Id);
                    if (h == IntPtr.Zero) continue;
                    try { if (EmptyWorkingSet(h)) done++; }
                    finally { CloseHandle(h); }
                }
                catch { }
                finally { p.Dispose(); }
            }
            return done;
        }

        static int MemoryListCommand(int command)
        {
            int cmd = command;
            return NtSetSystemInformation(SystemMemoryListInformation, ref cmd, sizeof(int));
        }

        // All return an NTSTATUS: 0 = success.
        public static int EmptyAllWorkingSets()      { return MemoryListCommand(MemoryEmptyWorkingSets); }
        public static int FlushModifiedList()        { return MemoryListCommand(MemoryFlushModifiedList); }
        public static int PurgeLowPriorityStandby()  { return MemoryListCommand(MemoryPurgeLowPriorityStandbyList); }
        public static int PurgeStandbyList()         { return MemoryListCommand(MemoryPurgeStandbyList); }

        // Writes pending registry changes to disk and releases the registry cache (Windows 8.1+).
        public static int FlushRegistryCache()
        {
            return NtSetSystemInformation(SystemRegistryReconciliationInformation, IntPtr.Zero, 0);
        }

        // Merges identical memory pages across processes (Windows 10+).
        public static int CombineMemoryPages()
        {
            MemoryCombineInformationEx info = new MemoryCombineInformationEx();
            return NtSetSystemInformation(SystemCombinePhysicalMemoryInformation, ref info, Marshal.SizeOf(info));
        }

        // Releases the system file cache working set.
        public static bool FlushSystemFileCache()
        {
            return SetSystemFileCacheSize(new IntPtr(-1), new IntPtr(-1), 0);
        }
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

function Get-MemoryStatus {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMB = [math]::Round($os.TotalVisibleMemorySize / 1KB)
    $availMB = [math]::Round($os.FreePhysicalMemory / 1KB)
    [pscustomobject]@{
        TotalMB     = $totalMB
        AvailableMB = $availMB
        InUseMB     = $totalMB - $availMB
        UsedPercent = [math]::Round((($totalMB - $availMB) / $totalMB) * 100)
    }
}

function Get-CpuLoad {
    $cpu = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"
    [int]$cpu.PercentProcessorTime
}

function Write-Log([string]$Message, [string]$Color = 'Gray') {
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor $Color
}

function Get-StepResult([string]$Name, [bool]$Ok) {
    if ($Ok) { "$Name OK" } else { "$Name not available" }
}

function Invoke-MemoryOptimize {
    $before = Get-MemoryStatus

    # 1. Working sets: every process individually, then the system-wide command
    #    (which also reaches protected processes the first pass cannot open).
    $trimmed = [MemOptMax.Native]::TrimAllWorkingSets()
    $steps = @()

    if ($script:IsAdmin) {
        $steps += Get-StepResult 'system working sets' ([MemOptMax.Native]::EmptyAllWorkingSets() -eq 0)
        # 2. System file cache
        $steps += Get-StepResult 'file cache' ([MemOptMax.Native]::FlushSystemFileCache())
        # 3. Registry cache
        $steps += Get-StepResult 'registry cache' ([MemOptMax.Native]::FlushRegistryCache() -eq 0)
        # 4. Merge duplicate pages
        $steps += Get-StepResult 'page combine' ([MemOptMax.Native]::CombineMemoryPages() -eq 0)

        if (-not $SkipStandby) {
            # 5. Write modified pages out so they can be released, then drop both standby lists
            $steps += Get-StepResult 'modified list' ([MemOptMax.Native]::FlushModifiedList() -eq 0)
            $steps += Get-StepResult 'low-priority standby' ([MemOptMax.Native]::PurgeLowPriorityStandby() -eq 0)
            $steps += Get-StepResult 'standby list' ([MemOptMax.Native]::PurgeStandbyList() -eq 0)
        }
    }

    # 6. This script's own memory
    [GC]::Collect(); [GC]::WaitForPendingFinalizers(); [GC]::Collect()

    if ($ClearClipboard) {
        cmd.exe /c "echo off | clip" | Out-Null
    }

    Start-Sleep -Milliseconds 500
    $after = Get-MemoryStatus
    $freed = $after.AvailableMB - $before.AvailableMB

    Write-Log ("Optimized: {0} processes trimmed. In use {1}% -> {2}%, available {3} MB -> {4} MB (freed {5} MB)" -f `
        $trimmed, $before.UsedPercent, $after.UsedPercent,
        $before.AvailableMB, $after.AvailableMB, $freed) 'Green'
    if ($steps.Count -gt 0) { Write-Log ("  Steps: {0}" -f ($steps -join ', ')) }
}

# --------------------------------------------------------------------------
# Install / uninstall the startup task
# --------------------------------------------------------------------------
$script:IsAdmin = Test-Admin

if ($Uninstall) {
    if (-not $script:IsAdmin) { throw 'Run PowerShell as Administrator to remove the startup task.' }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log "Startup task '$TaskName' removed." 'Yellow'
    return
}

if ($Install) {
    if (-not $script:IsAdmin) { throw 'Run PowerShell as Administrator to install the startup task.' }
    if ($ThresholdMB -le 0 -and $IntervalMinutes -le 0) {
        throw 'Give -ThresholdMB and/or -IntervalMinutes so the task knows when to optimize.'
    }

    $taskArgs = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Monitor -CheckSeconds {1}' -f $PSCommandPath, $CheckSeconds
    if ($ThresholdMB -gt 0)     { $taskArgs += " -ThresholdMB $ThresholdMB" }
    if ($IntervalMinutes -gt 0) { $taskArgs += " -IntervalMinutes $IntervalMinutes" }
    if ($IdleCpuPercent -gt 0)  { $taskArgs += " -IdleCpuPercent $IdleCpuPercent" }
    if ($ClearClipboard)        { $taskArgs += ' -ClearClipboard' }
    if ($SkipStandby)           { $taskArgs += ' -SkipStandby' }

    $user      = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgs
    $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force | Out-Null
    Write-Log "Startup task '$TaskName' installed. It starts at your next logon." 'Yellow'
    Write-Log "Start it now with: Start-ScheduledTask -TaskName '$TaskName'"
    return
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
if ($script:IsAdmin) {
    [void][MemOptMax.Native]::EnablePrivilege('SeDebugPrivilege')
    [void][MemOptMax.Native]::EnablePrivilege('SeProfileSingleProcessPrivilege')
    [void][MemOptMax.Native]::EnablePrivilege('SeIncreaseQuotaPrivilege')
} else {
    Write-Warning 'Not running as Administrator: only your own processes are trimmed; all other steps are skipped.'
}

$m = Get-MemoryStatus
Write-Log ("Memory: {0} MB total, {1} MB in use ({2}%), {3} MB available" -f `
    $m.TotalMB, $m.InUseMB, $m.UsedPercent, $m.AvailableMB) 'Cyan'

if (-not $Monitor) {
    Invoke-MemoryOptimize
    return
}

if ($ThresholdMB -le 0 -and $IntervalMinutes -le 0) {
    throw 'Monitor mode needs -ThresholdMB and/or -IntervalMinutes.'
}

$rules = @()
if ($ThresholdMB -gt 0)     { $rules += "available memory below $ThresholdMB MB" }
if ($IntervalMinutes -gt 0) { $rules += "every $IntervalMinutes minute(s)" }
Write-Log ("Monitoring. Optimizing when: {0}. Press Ctrl+C to stop." -f ($rules -join ' or ')) 'Cyan'

$lastRun  = Get-Date
$cooldown = [TimeSpan]::FromSeconds([math]::Max(60, $CheckSeconds * 2))   # avoid back-to-back runs

while ($true) {
    Start-Sleep -Seconds $CheckSeconds
    $now   = Get-Date
    $since = $now - $lastRun
    $due   = $false

    if ($IntervalMinutes -gt 0 -and $since.TotalMinutes -ge $IntervalMinutes) { $due = $true }

    if (-not $due -and $ThresholdMB -gt 0 -and $since -ge $cooldown) {
        if ((Get-MemoryStatus).AvailableMB -lt $ThresholdMB) { $due = $true }
    }

    if ($due -and $IdleCpuPercent -gt 0) {
        if ((Get-CpuLoad) -ge $IdleCpuPercent) { $due = $false }   # busy: try again next check
    }

    if ($due) {
        try { Invoke-MemoryOptimize } catch { Write-Log "Optimize failed: $_" 'Red' }
        $lastRun = Get-Date
    }
}