# Continuous network monitoring
function Start-NetworkMonitoring {
    param(
        [int]$RefreshInterval = 5,
        [int]$TopCount = 15
    )
    
    while ($true) {
        #Clear-Host
        Write-Host "Network Bandwidth Usage by Process - $(Get-Date)" -ForegroundColor Cyan
        Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
        Write-Host ("-" * 70) -ForegroundColor Gray
        
        try {
            # Get process network I/O
            $networkCounters = Get-Counter "\Process(*)\IO Data Bytes/sec" -MaxSamples 1 -ErrorAction SilentlyContinue
            
            $processStats = $networkCounters.CounterSamples | 
                Where-Object { $_.InstanceName -ne "_total" -and $_.InstanceName -ne "idle" -and $_.CookedValue -gt 1024 } |
                ForEach-Object {
                    $processName = $_.InstanceName -replace "#.*$", ""
                    [PSCustomObject]@{
                        Process = $processName
                        BytesPerSec = $_.CookedValue
                        KBPerSec = [math]::Round($_.CookedValue / 1KB, 2)
                        MBPerSec = [math]::Round($_.CookedValue / 1MB, 3)
                    }
                } |
                Group-Object Process |
                ForEach-Object {
                    [PSCustomObject]@{
                        Process = $_.Name
                        TotalKBPerSec = [math]::Round(($_.Group | Measure-Object KBPerSec -Sum).Sum, 2)
                        TotalMBPerSec = [math]::Round(($_.Group | Measure-Object MBPerSec -Sum).Sum, 3)
                        TotalBytesPerSec = ($_.Group | Measure-Object BytesPerSec -Sum).Sum
                    }
                } |
                Sort-Object TotalBytesPerSec -Descending |
                Select-Object -First $TopCount
            
            if ($processStats) {
                $processStats | Format-Table @{Name="Process";Expression={$_.Process};Width=25}, 
                                           @{Name="KB/s";Expression={$_.TotalKBPerSec};Align="Right";Width=10},
                                           @{Name="MB/s";Expression={$_.TotalMBPerSec};Align="Right";Width=10} -AutoSize
            } else {
                Write-Host "No significant network activity detected" -ForegroundColor Yellow
            }
            
        } catch {
            Write-Host "Error collecting data: $_" -ForegroundColor Red
        }
        
        Start-Sleep -Seconds $RefreshInterval
    }
}

# Start monitoring
Start-NetworkMonitoring -RefreshInterval 3 -TopCount 12