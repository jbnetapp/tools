# PowerShell equivalent to Unix 'top' command
param(
    [int]$RefreshInterval = 3,
    [int]$MaxProcesses = 35,
    [switch]$SortByCPU,
    [switch]$SortByMemory,
    [switch]$ShowAllProcesses,
    [switch]$NoColor,
    [string]$FilterProcess = "",
    [switch]$NoClear,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
PowerShell Top - Process Monitor

Usage: .\ps-top.ps1 [options]

Options:
  -RefreshInterval <seconds>  Update interval (default: 3)
  -MaxProcesses <number>      Number of processes to show (default: 35)
  -SortByCPU                  Sort by CPU usage (default)
  -SortByMemory              Sort by memory usage
  -ShowAllProcesses          Show all processes
  -NoColor                   Disable colored output
  -FilterProcess <name>       Filter by process name
  -NoClear                   Don't clear screen between updates
  -Help                      Show this help

Interactive Keys:
  q - Quit
  c - Sort by CPU
  m - Sort by memory
  r - Reverse sort order
  f - Set filter
  + - Increase refresh rate
  - - Decrease refresh rate

"@ -ForegroundColor Green
    return
}

# Initialize variables
$script:sortBy = if ($SortByMemory) { "Memory" } else { "CPU" }
$script:reverseSort = $false
$script:filterText = $FilterProcess
$script:refreshInterval = $RefreshInterval
$script:maxProcesses = if ($ShowAllProcesses) { 999 } else { $MaxProcesses }
$script:useColor = -not $NoColor.IsPresent

# Function to safely get CPU usage
function Get-SafeCPUUsage {
    $attempts = 0
    $maxAttempts = 3
    
    while ($attempts -lt $maxAttempts) {
        try {
            $attempts++
            
            # Method 1: Try Get-Counter with error handling
            $cpuCounter = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop
            $cpuValue = $cpuCounter.CounterSamples[0].CookedValue
            
            # Validate the result
            if ($cpuValue -ge 0 -and $cpuValue -le 100) {
                return [math]::Round($cpuValue, 1)
            }
            
            # If value is invalid, try alternative method
            throw "Invalid CPU value: $cpuValue"
            
        } catch {
            Write-Verbose "CPU counter attempt $attempts failed: $($_.Exception.Message)"
            
            if ($attempts -eq $maxAttempts) {
                # Fallback to WMI method
                try {
                    $wmiCpu = Get-CimInstance -ClassName Win32_PerfRawData_PerfOS_Processor | Where-Object Name -eq "_Total"
                    if ($wmiCpu) {
                        # Use a simple approximation
                        return Get-EstimatedCPUUsage
                    }
                } catch {
                    Write-Verbose "WMI CPU fallback failed: $($_.Exception.Message)"
                }
                
                # Final fallback - return estimate
                return Get-EstimatedCPUUsage
            }
            
            # Wait before retry
            Start-Sleep -Milliseconds 500
        }
    }
    
    return 0.0
}

# Function to get estimated CPU usage as last resort
function Get-EstimatedCPUUsage {
    try {
        # Use processor queue length as rough CPU activity indicator
        $queueLength = (Get-Counter "\System\Processor Queue Length" -ErrorAction SilentlyContinue).CounterSamples[0].CookedValue
        
        if ($queueLength -ne $null) {
            # Rough estimation: queue length to percentage
            $estimatedCpu = [math]::Min($queueLength * 10, 100)
            return [math]::Round($estimatedCpu, 1)
        }
    } catch {
        # Ignore errors in fallback
    }
    
    return 0.0
}

# Function to safely get load average
function Get-SafeLoadAverage {
    try {
        $loadAvg = (Get-Counter "\System\Processor Queue Length" -ErrorAction Stop).CounterSamples[0].CookedValue
        return [math]::Round($loadAvg, 2)
    } catch {
        return 0.0
    }
}

# Function to get system information - FIXED
function Get-SystemInfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRAM = $totalRAM - $freeRAM
    
    # Get CPU usage with robust error handling
    $cpuUsage = Get-SafeCPUUsage
    
    # Get load average (approximation using processor queue length)
    $loadAvg = Get-SafeLoadAverage
    
    # Get uptime
    $uptime = (Get-Date) - $os.LastBootUpTime
    
    return [PSCustomObject]@{
        Hostname = $env:COMPUTERNAME
        OS = "$($os.Caption) $($os.Version)"
        CPU = $cpu.Name
        CPUUsage = $cpuUsage
        TotalRAM = $totalRAM
        UsedRAM = $usedRAM
        FreeRAM = $freeRAM
        RAMPercent = [math]::Round(($usedRAM / $totalRAM) * 100, 1)
        LoadAvg = $loadAvg
        Uptime = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
        Processes = (Get-Process | Measure-Object).Count
        CurrentTime = Get-Date -Format "HH:mm:ss"
    }
}

# Function to safely get process CPU data
function Get-ProcessCPUData {
    $cpuData = @{}
    
    try {
        # Get process CPU counters with better error handling
        $processCounters = Get-Counter "\Process(*)\% Processor Time" -ErrorAction SilentlyContinue -MaxSamples 1
        
        if ($processCounters -and $processCounters.CounterSamples) {
            foreach ($sample in $processCounters.CounterSamples) {
                try {
                    $processName = $sample.InstanceName
                    $cpuValue = $sample.CookedValue
                    
                    # Skip invalid entries
                    if ($processName -eq "_Total" -or $processName -eq "Idle" -or $cpuValue -lt 0) {
                        continue
                    }
                    
                    # Validate and store CPU value
                    if ($cpuValue -ge 0 -and $cpuValue -le 100) {
                        $cpuData[$processName] = [math]::Round($cpuValue, 1)
                    }
                } catch {
                    # Skip individual counter errors
                    continue
                }
            }
        }
    } catch {
        Write-Verbose "Process CPU counter collection failed: $($_.Exception.Message)"
    }
    
    return $cpuData
}

# Function to get detailed process information - IMPROVED
function Get-ProcessInfo {
    param([string]$Filter = "")
    
    # Get all processes
    $processes = Get-Process | Where-Object { 
        if ($Filter) { 
            $_.ProcessName -like "*$Filter*" 
        } else { 
            $true 
        } 
    }
    
    # Get CPU performance data more safely
    $cpuData = Get-ProcessCPUData
    
    $processData = foreach ($process in $processes) {
        try {
            # Get CPU usage from our safe method
            $cpuUsage = if ($cpuData.ContainsKey($process.ProcessName)) {
                $cpuData[$process.ProcessName]
            } else {
                0.0
            }
            
            # Get memory info
            $workingSet = $process.WorkingSet64 / 1MB
            $virtualMemory = $process.VirtualMemorySize64 / 1MB
            
            # Get process details
            $startTime = if ($process.StartTime) { $process.StartTime } else { Get-Date }
            $runTime = (Get-Date) - $startTime
            
            # Get user name safely
            $userName = try { 
                $process.StartInfo.UserName 
            } catch { 
                "N/A" 
            }
            
            # Get process path safely
            $processPath = try { 
                $process.MainModule.FileName 
            } catch { 
                "N/A" 
            }
            
            [PSCustomObject]@{
                PID = $process.Id
                ProcessName = $process.ProcessName
                CPU = $cpuUsage
                Memory = [math]::Round($workingSet, 1)
                VirtualMem = [math]::Round($virtualMemory, 1)
                Handles = $process.HandleCount
                Threads = $process.Threads.Count
                Status = $process.Responding
                Priority = $process.BasePriority
                StartTime = $startTime
                RunTime = "$($runTime.Days)d $($runTime.Hours):$($runTime.Minutes.ToString('00'))"
                User = $userName
                Path = $processPath
            }
        } catch {
            # Skip processes that can't be accessed
            continue
        }
    }
    
    # Sort processes
    switch ($script:sortBy) {
        "CPU" { 
            $sorted = $processData | Sort-Object CPU -Descending 
        }
        "Memory" { 
            $sorted = $processData | Sort-Object Memory -Descending 
        }
        "PID" { 
            $sorted = $processData | Sort-Object PID 
        }
        "Name" { 
            $sorted = $processData | Sort-Object ProcessName 
        }
    }
    
    if ($script:reverseSort) {
        [array]::Reverse($sorted)
    }
    
    return $sorted | Select-Object -First $script:maxProcesses
}

# Function to display colored text
function Write-ColorText {
    param([string]$Text, [string]$Color = "White")
    
    if ($script:useColor) {
        Write-Host $Text -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Text -NoNewline
    }
}

# Function to display the header
function Show-Header {
    param($SystemInfo)
   
    if (-not $NoClear.IsPresent) { 
        Clear-Host
    } 

    # Title and time
    Write-ColorText "PowerShell Top - " "Cyan"
    Write-ColorText $SystemInfo.CurrentTime "Yellow"
    Write-ColorText " up " "White"
    Write-ColorText $SystemInfo.Uptime "Green"
    Write-ColorText ", " "White"
    Write-ColorText "$($SystemInfo.Processes) processes" "Green"
    Write-Host ""
    
    # System info
    Write-ColorText "CPU: " "Cyan"
    $cpuColor = if ($SystemInfo.CPUUsage -gt 80) { "Red" } elseif ($SystemInfo.CPUUsage -gt 60) { "Yellow" } else { "Green" }
    Write-ColorText "$($SystemInfo.CPUUsage)% " $cpuColor
    Write-ColorText "Load avg: " "Cyan"
    Write-ColorText "$($SystemInfo.LoadAvg) " "White"
    Write-Host ""
    
    # Memory info
    Write-ColorText "Memory: " "Cyan"
    Write-ColorText "$($SystemInfo.UsedRAM)GB used, " "White"
    Write-ColorText "$($SystemInfo.FreeRAM)GB free, " "White"
    Write-ColorText "$($SystemInfo.TotalRAM)GB total " "White"
    $memColor = if ($SystemInfo.RAMPercent -gt 80) { "Red" } elseif ($SystemInfo.RAMPercent -gt 60) { "Yellow" } else { "Green" }
    Write-ColorText "($($SystemInfo.RAMPercent)%)" $memColor
    Write-Host ""
    
    # Current settings
    Write-ColorText "Sort: " "Cyan"
    Write-ColorText $script:sortBy "Yellow"
    if ($script:filterText) {
        Write-ColorText " | Filter: " "Cyan"
        Write-ColorText $script:filterText "Yellow"
    }
    Write-ColorText " | Refresh: " "Cyan"
    Write-ColorText "$($script:refreshInterval)s " "Yellow"
    Write-ColorText "| Max: " "Cyan"
    Write-ColorText "$($script:maxProcesses) " "Yellow"
    Write-Host ""
    Write-Host ""
}

# Function to display process table
function Show-ProcessTable {
    param($ProcessData)
    
    # Header
    $header = "{0,-8} {1,-20} {2,6} {3,8} {4,8} {5,7} {6,7} {7,8} {8,10}" -f "PID", "NAME", "CPU%", "MEM(MB)", "VIRT(MB)", "HANDLES", "THREADS", "PRIORITY", "TIME"
    Write-ColorText $header "White"
    Write-Host ""
    Write-ColorText ("-" * 90) "DarkGray"
    Write-Host ""
    
    # Process rows
    foreach ($proc in $ProcessData) {
        # Color coding based on resource usage
        $pidColor = "White"
        $nameColor = if ($proc.Status) { "White" } else { "Red" }
        $cpuColor = if ($proc.CPU -gt 50) { "Red" } elseif ($proc.CPU -gt 20) { "Yellow" } else { "Green" }
        $memColor = if ($proc.Memory -gt 1000) { "Red" } elseif ($proc.Memory -gt 500) { "Yellow" } else { "Green" }
        
        $processName = if ($proc.ProcessName.Length -gt 20) { $proc.ProcessName.Substring(0, 17) + "..." } else { $proc.ProcessName }
        
        if ($script:useColor) {
            Write-Host ("{0,-8} " -f $proc.PID) -ForegroundColor $pidColor -NoNewline
            Write-Host ("{0,-20} " -f $processName) -ForegroundColor $nameColor -NoNewline
            Write-Host ("{0,6} " -f $proc.CPU) -ForegroundColor $cpuColor -NoNewline
            Write-Host ("{0,8} " -f $proc.Memory) -ForegroundColor $memColor -NoNewline
            Write-Host ("{0,8} {1,7} {2,7} {3,8} {4,10}" -f $proc.VirtualMem, $proc.Handles, $proc.Threads, $proc.Priority, $proc.RunTime) -ForegroundColor White
        } else {
            $line = "{0,-8} {1,-20} {2,6} {3,8} {4,8} {5,7} {6,7} {7,8} {8,10}" -f 
                $proc.PID, 
                $processName, 
                $proc.CPU, 
                $proc.Memory, 
                $proc.VirtualMem, 
                $proc.Handles, 
                $proc.Threads, 
                $proc.Priority, 
                $proc.RunTime
            Write-Host $line
        }
    }
}

# Function to handle keyboard input
function Get-KeyInput {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        
        switch ($key.Key) {
            'Q' { 
                return 'quit' 
            }
            'C' { 
                $script:sortBy = "CPU"
                return 'refresh'
            }
            'M' { 
                $script:sortBy = "Memory"
                return 'refresh'
            }
            'R' { 
                $script:reverseSort = -not $script:reverseSort
                return 'refresh'
            }
            'F' { 
                Write-Host "`nEnter filter text (empty to clear): " -NoNewline
                $script:filterText = Read-Host
                return 'refresh'
            }
            'Add' { 
                $script:refreshInterval = [Math]::Min($script:refreshInterval + 1, 60)
                return 'continue'
            }
            'Subtract' { 
                $script:refreshInterval = [Math]::Max($script:refreshInterval - 1, 1)
                return 'continue'
            }
        }
    }
    return 'continue'
}

# Enhanced main monitoring loop with error handling
function Start-TopMonitoring {
    $errorCount = 0
    $maxErrors = 10
    
    while ($true) {
        try {
            # Get system and process information
            $systemInfo = Get-SystemInfo
            $processData = Get-ProcessInfo -Filter $script:filterText
            
            # Display everything
            Show-Header $systemInfo
            Show-ProcessTable $processData
            
            # Reset error count on successful iteration
            $errorCount = 0
            
            # Handle keyboard input
            $keyResult = Get-KeyInput
            if ($keyResult -eq 'quit') {
                throw "User quit"
            } elseif ($keyResult -eq 'refresh') {
                continue
            }
            
            # Wait for refresh interval
            Start-Sleep -Seconds $script:refreshInterval
            
        } catch {
            if ($_.Exception.Message -eq "User quit") {
                throw $_
            }
            
            $errorCount++
            Write-Host "Error occurred (attempt $errorCount/$maxErrors): $($_.Exception.Message)" -ForegroundColor Yellow
            
            if ($errorCount -ge $maxErrors) {
                Write-Host "Too many consecutive errors. Exiting." -ForegroundColor Red
                break
            }
            
            # Wait longer after errors
            Start-Sleep -Seconds ($script:refreshInterval * 2)
        }
    }
}

# Main execution
try {
    Write-Host "PowerShell Top - Press 'q' to quit, other keys for controls" -ForegroundColor Green
    Write-Host "Controls: c=CPU sort, m=Memory sort, r=reverse, f=filter, +/- adjust refresh" -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    
    # Use the enhanced monitoring function
    Start-TopMonitoring
    
} catch [System.OperationCanceledException] {
    # Handle Ctrl-C gracefully
    Write-Host "`nOperation cancelled by user." -ForegroundColor Yellow
} catch {
    if ($_.Exception.Message -ne "User quit") {
        Write-Host "`nError: $_" -ForegroundColor Red
    }
} finally {
    if (-not $NoClear.IsPresent) { 
        Clear-Host
    }
    Write-Host "PowerShell Top terminated." -ForegroundColor Green
}