<#
.SYNOPSIS
    Display CPU usage for each individual CPU core - OPTIMIZED VERSION
.DESCRIPTION
    This script shows real-time CPU usage percentage for each processor core
    with optimized performance and no screen blanking
.AUTHOR
    System Administrator
.VERSION
    1.2 (Performance Optimized)
#>

# Cache system information globally to avoid repeated slow calls
$script:SystemInfoCache = $null

# Function to get system information once and cache it
function Initialize-SystemInfo {
    if (-not $script:SystemInfoCache) {
        Write-Host "Loading system information (one-time setup)..." -ForegroundColor Yellow
        try {
            # Get system info once and cache it
            $script:SystemInfoCache = @{
                CPUName = (Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1).Name
                LogicalProcessors = (Get-CimInstance -ClassName Win32_ComputerSystem).NumberOfLogicalProcessors
                PhysicalProcessors = (Get-CimInstance -ClassName Win32_ComputerSystem).NumberOfProcessors
                LoadTime = Get-Date
            }
            Write-Host "System information loaded successfully!" -ForegroundColor Green
        } catch {
            Write-Host "Warning: Could not load system information" -ForegroundColor Yellow
            $script:SystemInfoCache = @{
                CPUName = "Unknown CPU"
                LogicalProcessors = "Unknown"
                PhysicalProcessors = "Unknown" 
                LoadTime = Get-Date
            }
        }
    }
}

# Function to display CPU information - OPTIMIZED
function Show-CPUInfo {
    param(
        [int]$SampleInterval = 1,
        [int]$SampleCount = 1,
        [switch]$SkipSystemInfo
    )
    
    try {
        # Only show header for first run or when explicitly requested
        if (-not $SkipSystemInfo) {
            Write-Host "=== CPU Core Usage Monitor ===" -ForegroundColor Green
            Write-Host ""
            
            # Use cached system information
            Initialize-SystemInfo
            
            Write-Host "System Information:" -ForegroundColor Cyan
            Write-Host "CPU: $($script:SystemInfoCache.CPUName)" -ForegroundColor White
            Write-Host "Physical Processors: $($script:SystemInfoCache.PhysicalProcessors)" -ForegroundColor White
            Write-Host "Logical Processors: $($script:SystemInfoCache.LogicalProcessors)" -ForegroundColor White
            Write-Host ""
        }
        
        # Display timestamp
        $timestamp = Get-Date -Format "HH:mm:ss"
        Write-Host "Sample at: $timestamp" -ForegroundColor Gray
        
        # Get CPU counter data (this is fast)
        $cpuCounters = Get-Counter "\Processor(*)\% Processor Time" -SampleInterval $SampleInterval -MaxSamples $SampleCount -ErrorAction SilentlyContinue
        
        if (-not $cpuCounters) {
            Write-Host "Error: Could not retrieve CPU counters" -ForegroundColor Red
            return
        }
        
        # Process CPU data
        $cpuData = @()
        $totalCpuUsage = 0
        $coreCount = 0
        
        foreach ($sample in $cpuCounters.CounterSamples) {
            $instanceName = $sample.InstanceName
            $cpuUsage = [math]::Round($sample.CookedValue, 2)
            
            if ($instanceName -eq "_Total") {
                $totalCpuUsage = $cpuUsage
            } else {
                $coreCount++
                $cpuData += [PSCustomObject]@{
                    Core = "Core $instanceName"
                    Usage = $cpuUsage
                    Status = Get-CPUStatus $cpuUsage
                    BarGraph = Get-UsageBar $cpuUsage
                }
            }
        }
        
        # Sort cores numerically
        $cpuData = $cpuData | Sort-Object { [int]($_.Core -replace 'Core ') }
        
        # Display individual CPU cores
        Write-Host ""
        Write-Host "Individual CPU Core Usage:" -ForegroundColor Cyan
        Write-Host ("-" * 75) -ForegroundColor Gray
        Write-Host ("{0,-12} {1,-10} {2,-10} {3,-35}" -f "Core", "Usage %", "Status", "Usage Bar") -ForegroundColor White
        Write-Host ("-" * 75) -ForegroundColor Gray
        
        foreach ($cpu in $cpuData) {
            $color = switch ($cpu.Usage) {
                {$_ -lt 25} { "Green" }
                {$_ -lt 50} { "Yellow" }
                {$_ -lt 75} { "DarkYellow" }
                default { "Red" }
            }
            
            Write-Host ("{0,-12} {1,-10} {2,-10} {3,-35}" -f $cpu.Core, "$($cpu.Usage)%", $cpu.Status, $cpu.BarGraph) -ForegroundColor $color
        }
        
        Write-Host ("-" * 75) -ForegroundColor Gray
        
        # Display summary
        Write-Host ""
        Write-Host "Summary:" -ForegroundColor Cyan
        Write-Host "Total CPU Cores: $coreCount" -ForegroundColor White
        Write-Host "Average CPU Usage: $totalCpuUsage%" -ForegroundColor $(if ($totalCpuUsage -lt 50) { "Green" } elseif ($totalCpuUsage -lt 75) { "Yellow" } else { "Red" })
        
        return $totalCpuUsage
        
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
        return 0
    }
}

# Function to determine CPU status
function Get-CPUStatus {
    param([double]$usage)
    
    switch ($usage) {
        {$_ -lt 25} { return "Low" }
        {$_ -lt 50} { return "Normal" }
        {$_ -lt 75} { return "High" }
        default { return "Critical" }
    }
}

# Function to create a visual usage bar
function Get-UsageBar {
    param([double]$usage)
    
    $barLength = 20
    $filledLength = [math]::Round(($usage / 100) * $barLength)
    $emptyLength = $barLength - $filledLength
    
    $filledChar = "#"
    $emptyChar = "-"
    
    $bar = $filledChar * $filledLength + $emptyChar * $emptyLength
    return "[$bar] $usage%"
}

# Optimized continuous monitoring function
function Start-CPUMonitoring {
    param(
        [int]$RefreshInterval = 2,
        [switch]$NoClear
    )
    
    Write-Host "Starting optimized CPU monitoring (Press Ctrl+C to stop)..." -ForegroundColor Green
    Write-Host ""
    
    # Initialize system info once
    Initialize-SystemInfo
    
    try {
        $iteration = 0
        $lastClearTime = Get-Date
        
        while ($true) {
            $iteration++
            $currentTime = Get-Date
            
            # Smart screen management
            $shouldClear = $false
            if (-not $NoClear) {
                # Clear screen every 60 seconds or every 30 iterations, whichever comes first
                $timeSinceLastClear = ($currentTime - $lastClearTime).TotalSeconds
                if ($timeSinceLastClear -gt 60 -or $iteration % 30 -eq 1) {
                    $shouldClear = $true
                    $lastClearTime = $currentTime
                }
            }
            
            if ($shouldClear -and $iteration -gt 1) {
                Clear-Host
                Write-Host "=== CPU Monitor (Running for $([math]::Round(($currentTime - $script:SystemInfoCache.LoadTime).TotalMinutes, 1)) minutes) ===" -ForegroundColor Green
                Write-Host "Iteration: $iteration | Refresh Rate: $RefreshInterval seconds" -ForegroundColor Yellow
            } elseif ($iteration -eq 1) {
                # First iteration - show full header
                Clear-Host
            }
            
            # Show CPU info (skip system info after first run for speed)
            $cpuUsage = Show-CPUInfo -SkipSystemInfo:($iteration -gt 1)
            
            # Show top CPU processes occasionally
            #if ($iteration % 10 -eq 1) {
            #    Write-Host ""
            #    Write-Host "Top CPU Processes:" -ForegroundColor Cyan
            #    Get-Process | Sort-Object CPU -Descending | Select-Object -First 3 ProcessName, @{Name="CPU%";Expression={[math]::Round($_.CPU,2)}} | Format-Table -AutoSize
            #}

            Write-Host ""
            Write-Host "Top CPU Processes since startup :" -ForegroundColor Cyan
            Get-Process | Sort-Object CPU -Descending | Select-Object -First 3 ProcessName, @{Name="CPU%";Expression={[math]::Round($_.CPU,2)}} | Format-Table -AutoSize
            
            # Status line
            Write-Host ""
            Write-Host "Next update in $RefreshInterval seconds... (Ctrl+C to stop) [Iteration: $iteration]" -ForegroundColor Gray
            
            Start-Sleep -Seconds $RefreshInterval
        }
    } catch [System.OperationCanceledException] {
        Write-Host ""
        Write-Host "Monitoring stopped by user." -ForegroundColor Yellow
    } catch {
        Write-Host "Error in monitoring loop: $_" -ForegroundColor Red
    }
}

# Function to show live updating CPU without clearing screen
function Start-LiveCPUDisplay {
    param(
        [int]$RefreshInterval = 1
    )
    
    Write-Host "Starting LIVE CPU display (no screen clearing)..." -ForegroundColor Green
    Initialize-SystemInfo
    
    try {
        $iteration = 0
        while ($true) {
            $iteration++
            
            # Just show timestamp and total CPU usage for live view
            $timestamp = Get-Date -Format "HH:mm:ss.fff"
            
            # Quick CPU check
            $cpuCounter = Get-Counter "\Processor(_Total)\% Processor Time" -MaxSamples 1 -ErrorAction SilentlyContinue
            if ($cpuCounter) {
                $totalCpu = [math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2)
                $color = if ($totalCpu -lt 50) { "Green" } elseif ($totalCpu -lt 75) { "Yellow" } else { "Red" }
                
                Write-Host "[$timestamp] Total CPU: $totalCpu% $(Get-CPUStatus $totalCpu) [$('#' * [math]::Round($totalCpu/5))]" -ForegroundColor $color
            }
            
            Start-Sleep -Seconds $RefreshInterval
        }
    } catch [System.OperationCanceledException] {
        Write-Host ""
        Write-Host "Live display stopped." -ForegroundColor Yellow
    }
}

# Enhanced export function
function Export-CPUData {
    param(
        [string]$OutputPath = ".\cpu_usage_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
        [int]$SampleCount = 1
    )
    
    try {
        Write-Host "Collecting CPU data for export..." -ForegroundColor Yellow
        
        $cpuCounters = Get-Counter "\Processor(*)\% Processor Time" -SampleInterval 1 -MaxSamples $SampleCount
        $cpuData = @()
        
        foreach ($sample in $cpuCounters.CounterSamples) {
            $cpuData += [PSCustomObject]@{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Core = $sample.InstanceName
                Usage = [math]::Round($sample.CookedValue, 2)
                Status = Get-CPUStatus $sample.CookedValue
            }
        }
        
        $cpuData | Export-Csv -Path $OutputPath -NoTypeInformation
        Write-Host "CPU data exported to: $OutputPath" -ForegroundColor Green
        
    } catch {
        Write-Host "Error exporting data: $_" -ForegroundColor Red
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host ""
    Write-Host "=== Optimized CPU Information Script ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Choose an option:" -ForegroundColor Cyan
    Write-Host "1. Show current CPU usage (one-time)" -ForegroundColor White
    Write-Host "2. Start continuous monitoring (optimized)" -ForegroundColor White
    Write-Host "3. Start live CPU display (no clearing)" -ForegroundColor White
    Write-Host "4. Export CPU data to CSV" -ForegroundColor White
    Write-Host "5. Show system information only" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Enter your choice (1-5)"
    
    switch ($choice) {
        "1" {
            Show-CPUInfo
        }
        "2" {
            $interval = Read-Host "Enter refresh interval in seconds (default: 2)"
            if ([string]::IsNullOrEmpty($interval)) { $interval = 2 }
            
            $noClear = Read-Host "Disable screen clearing? (y/N)"
            $noClearSwitch = $noClear -eq 'y'
            
            Start-CPUMonitoring -RefreshInterval $interval -NoClear:$noClearSwitch
        }
        "3" {
            $interval = Read-Host "Enter refresh interval in seconds (default: 1)"
            if ([string]::IsNullOrEmpty($interval)) { $interval = 1 }
            Start-LiveCPUDisplay -RefreshInterval $interval
        }
        "4" {
            $samples = Read-Host "Number of samples to collect (default: 1)"
            if ([string]::IsNullOrEmpty($samples)) { $samples = 1 }
            
            $path = Read-Host "Enter output path (press Enter for default)"
            if ([string]::IsNullOrEmpty($path)) {
                Export-CPUData -SampleCount $samples
            } else {
                Export-CPUData -OutputPath $path -SampleCount $samples
            }
        }
        "5" {
            Initialize-SystemInfo
            Write-Host ""
            Write-Host "System Information:" -ForegroundColor Cyan
            Write-Host "CPU: $($script:SystemInfoCache.CPUName)" -ForegroundColor White
            Write-Host "Physical Processors: $($script:SystemInfoCache.PhysicalProcessors)" -ForegroundColor White
            Write-Host "Logical Processors: $($script:SystemInfoCache.LogicalProcessors)" -ForegroundColor White
            Write-Host "Loaded at: $($script:SystemInfoCache.LoadTime)" -ForegroundColor Gray
        }
        default {
            Write-Host "Invalid choice. Running default CPU display..." -ForegroundColor Yellow
            Show-CPUInfo
        }
    }
}