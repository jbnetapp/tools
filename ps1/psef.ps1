# Enhanced CPU monitoring script with real-time updates
param(
    [int]$TopProcesses = 20,
    [int]$RefreshInterval = 2,
    [switch]$ContinuousMode,
    [switch]$ShowAll
)

function Get-ProcessCPUUsage {
    param(
        [int]$Top = 20,
        [switch]$ShowAllProcesses
    )
    
    # Get CPU usage using Get-Counter for more accurate real-time data
    $cpuCounters = Get-Counter "\Process(*)\% Processor Time" -ErrorAction SilentlyContinue
    $processes = Get-Process
    
    $processData = foreach ($process in $processes) {
        try {
            # Find matching counter for this process
            $counterPath = "\Process($($process.ProcessName))\% Processor Time"
            $cpuCounter = $cpuCounters.CounterSamples | Where-Object { $_.Path -like "*$($process.ProcessName)*" } | Select-Object -First 1
            
            if ($cpuCounter) {
                $cpuPercent = [math]::Round($cpuCounter.CookedValue, 2)
            } else {
                $cpuPercent = 0
            }
            
            [PSCustomObject]@{
                ProcessName = $process.ProcessName
                PID = $process.Id
                'CPU%' = $cpuPercent
                'Memory(MB)' = [math]::Round($process.WorkingSet64 / 1MB, 2)
                'Handles' = $process.HandleCount
                'Threads' = $process.Threads.Count
                'StartTime' = if ($process.StartTime) { $process.StartTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }
            }
        }
        catch {
            # Skip processes that can't be accessed
            continue
        }
    }
    
    if ($ShowAllProcesses) {
        return $processData | Sort-Object 'CPU%' -Descending
    } else {
        return $processData | Sort-Object 'CPU%' -Descending | Select-Object -First $Top
    }
}

function Show-CPUUsage {
    param(
        [int]$Top = 20,
        [switch]$ShowAll
    )
    
    Clear-Host
    Write-Host "=== Windows 11 Process CPU Usage Monitor ===" -ForegroundColor Cyan
    Write-Host "Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
    Write-Host "Showing top $Top processes by CPU usage" -ForegroundColor Green
    Write-Host "Press Ctrl+C to exit" -ForegroundColor Red
    Write-Host ""
    
    $data = Get-ProcessCPUUsage -Top $Top -ShowAllProcesses:$ShowAll
    $data | Format-Table -AutoSize
    
    # Show system summary
    $totalCPU = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
    $totalRAM = Get-CimInstance Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory
    $availableRAM = Get-Counter "\Memory\Available MBytes" | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue
    $usedRAM = ($totalRAM / 1MB) - $availableRAM
    
    Write-Host "=== System Summary ===" -ForegroundColor Cyan
    Write-Host "Total CPU Usage: $([math]::Round($totalCPU, 2))%" -ForegroundColor $(if($totalCPU -gt 80) {"Red"} elseif($totalCPU -gt 60) {"Yellow"} else {"Green"})
    Write-Host "RAM Usage: $([math]::Round($usedRAM, 2)) MB / $([math]::Round($totalRAM/1MB, 2)) MB ($([math]::Round(($usedRAM/($totalRAM/1MB))*100, 2))%)" -ForegroundColor $(if(($usedRAM/($totalRAM/1MB))*100 -gt 80) {"Red"} elseif(($usedRAM/($totalRAM/1MB))*100 -gt 60) {"Yellow"} else {"Green"})
}

# Main execution
if ($ContinuousMode) {
    while ($true) {
        Show-CPUUsage -Top $TopProcesses -ShowAll:$ShowAll
        Start-Sleep -Seconds $RefreshInterval
    }
} else {
    Show-CPUUsage -Top $TopProcesses -ShowAll:$ShowAll
}
