#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Monitor Windows Kernel CPU activity in real-time
.DESCRIPTION
    Displays kernel vs user CPU time and identifies processes with high kernel CPU usage
.PARAMETER RefreshInterval
    Interval in seconds between updates (default: 2)
.PARAMETER TopProcesses
    Number of top processes to display (default: 15)
#>

param(
    [int]$RefreshInterval = 2,
    [int]$TopProcesses = 15
)

function Get-KernelCPUStats {
    try {
        # Get overall CPU statistics
        $privilegedTime = (Get-Counter '\Processor(_Total)\% Privileged Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
        $userTime = (Get-Counter '\Processor(_Total)\% User Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
        $processorTime = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
        
        return @{
            KernelCPU = [math]::Round($privilegedTime, 2)
            UserCPU = [math]::Round($userTime, 2)
            TotalCPU = [math]::Round($processorTime, 2)
        }
    }
    catch {
        Write-Warning "Error getting CPU statistics: $_"
        return $null
    }
}

function Get-ProcessKernelCPU {
    param([int]$TopCount = 15)
    
    try {
        $processes = Get-Process | Where-Object { $_.Id -ne 0 } | ForEach-Object {
            try {
                $kernelTime = ($_.TotalProcessorTime.TotalMilliseconds - $_.UserProcessorTime.TotalMilliseconds)
                
                [PSCustomObject]@{
                    ProcessName = $_.ProcessName
                    PID = $_.Id
                    KernelTimeMS = [math]::Round($kernelTime, 2)
                    UserTimeMS = [math]::Round($_.UserProcessorTime.TotalMilliseconds, 2)
                    TotalTimeMS = [math]::Round($_.TotalProcessorTime.TotalMilliseconds, 2)
                    Threads = $_.Threads.Count
                    HandleCount = $_.HandleCount
                }
            }
            catch {
                # Skip processes we can't access
                $null
            }
        }
        
        return $processes | Where-Object { $_ -ne $null } | 
               Sort-Object KernelTimeMS -Descending | 
               Select-Object -First $TopCount
    }
    catch {
        Write-Warning "Error getting process information: $_"
        return @()
    }
}

function Show-Dashboard {
    param(
        [hashtable]$CPUStats,
        [array]$TopProcesses
    )
    
    Clear-Host
    
    # Header
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host " WINDOWS KERNEL CPU MONITOR" -ForegroundColor Cyan
    Write-Host " $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ("=" * 100) -ForegroundColor Cyan
    Write-Host ""
    
    # Overall CPU Statistics
    if ($CPUStats) {
        Write-Host " OVERALL CPU USAGE:" -ForegroundColor Yellow
        Write-Host "  Total CPU:    $($CPUStats.TotalCPU)%" -ForegroundColor White
        Write-Host "  Kernel Mode:  $($CPUStats.KernelCPU)%" -ForegroundColor Red
        Write-Host "  User Mode:    $($CPUStats.UserCPU)%" -ForegroundColor Green
        Write-Host ""
        
        # Visual bar for kernel vs user
        $kernelBar = [math]::Round(($CPUStats.KernelCPU / 100) * 50)
        $userBar = [math]::Round(($CPUStats.UserCPU / 100) * 50)
        
        Write-Host "  [" -NoNewline
        Write-Host ("#" * $kernelBar) -NoNewline -ForegroundColor Red
        Write-Host ("#" * $userBar) -NoNewline -ForegroundColor Green
        Write-Host (" " * (50 - $kernelBar - $userBar)) -NoNewline
        Write-Host "]"
        Write-Host "   " -NoNewline
        Write-Host "Kernel" -NoNewline -ForegroundColor Red
        Write-Host " | " -NoNewline
        Write-Host "User" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host ("-" * 100) -ForegroundColor DarkGray
    Write-Host ""
    
    # Top Processes by Kernel CPU Time
    Write-Host " TOP $($TopProcesses.Count) PROCESSES BY KERNEL CPU TIME:" -ForegroundColor Yellow
    Write-Host ""
    
    # Table header
    $header = "{0,-30} {1,8} {2,15} {3,15} {4,10} {5,10}" -f "Process", "PID", "Kernel (ms)", "User (ms)", "Threads", "Handles"
    Write-Host $header -ForegroundColor Cyan
    Write-Host ("-" * 100) -ForegroundColor DarkGray
    
    # Table rows
    foreach ($proc in $TopProcesses) {
        $row = "{0,-30} {1,8} {2,15:N0} {3,15:N0} {4,10} {5,10}" -f `
            $proc.ProcessName.Substring(0, [Math]::Min(30, $proc.ProcessName.Length)),
            $proc.PID,
            $proc.KernelTimeMS,
            $proc.UserTimeMS,
            $proc.Threads,
            $proc.HandleCount
        
        # Color code based on kernel time
        if ($proc.KernelTimeMS -gt 100000) {
            Write-Host $row -ForegroundColor Red
        }
        elseif ($proc.KernelTimeMS -gt 10000) {
            Write-Host $row -ForegroundColor Yellow
        }
        else {
            Write-Host $row -ForegroundColor White
        }
    }
    
    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor DarkGray
    Write-Host " Press Ctrl+C to exit | Refresh interval: $RefreshInterval seconds" -ForegroundColor Gray
    Write-Host ""
}

# Main monitoring loop
Write-Host "Starting Kernel CPU Monitor..." -ForegroundColor Green
Write-Host "Collecting initial data..." -ForegroundColor Gray
Write-Host ""

try {
    while ($true) {
        # Collect data
        $cpuStats = Get-KernelCPUStats
        $topProcs = Get-ProcessKernelCPU -TopCount $TopProcesses
        
        # Display dashboard
        Show-Dashboard -CPUStats $cpuStats -TopProcesses $topProcs
        
        # Wait before next update
        Start-Sleep -Seconds $RefreshInterval
    }
}
catch {
    Write-Host ""
    Write-Host "Monitor stopped." -ForegroundColor Yellow
    exit
}