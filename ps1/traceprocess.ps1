# Process Activity Tracer
param(
    [Parameter(Mandatory=$true)]
    [string]$ProcessName,
    [int]$ProcessId = 0,
    [int]$RefreshInterval = 2,
    [switch]$ShowFileActivity,
    [switch]$ShowNetworkConnections,
    [switch]$ShowModules,
    [switch]$LogToFile,
    [string]$LogPath = "process-trace.log",
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Process Activity Tracer

Usage: .\trace-process.ps1 -ProcessName <name> [options]

Parameters:
  -ProcessName <name>         Process name to trace (required)
  -ProcessId <id>            Specific process ID (optional)
  -RefreshInterval <seconds>  Update interval (default: 2)
  -ShowFileActivity          Show file handles and operations
  -ShowNetworkConnections    Show network connections
  -ShowModules               Show loaded modules/DLLs
  -LogToFile                 Log output to file
  -LogPath <path>            Log file path (default: process-trace.log)
  -Help                      Show this help

Examples:
  .\trace-process.ps1 -ProcessName "notepad"
  .\trace-process.ps1 -ProcessName "chrome" -ShowNetworkConnections
  .\trace-process.ps1 -ProcessId 1234 -LogToFile

Interactive Commands:
  q - Quit
  f - Toggle file activity
  n - Toggle network connections
  m - Toggle modules
  + - Increase refresh rate
  - - Decrease refresh rate

"@ -ForegroundColor Green
    return
}

# Initialize variables
$script:showFiles = $ShowFileActivity.IsPresent
$script:showNetwork = $ShowNetworkConnections.IsPresent
$script:showModules = $ShowModules.IsPresent
$script:logToFile = $LogToFile.IsPresent
$script:refreshInterval = $RefreshInterval

# Function to write output (console and optionally file) - FIXED

function Set-CursorToTop {
    try {
        [Console]::SetCursorPosition(0, 0)
        [Console]::CursorVisible = $false
    } catch {
        # Fallback if console positioning fails
        Write-Host "`r" -NoNewline
    }
}

function Reset-CursorVisibility {
    try {
        [Console]::CursorVisible = $true
    } catch {
        # Silent fail
    }
}


function Write-TraceOutput {
    param([string]$Message, [string]$Color = "White")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    
    # Validate color parameter
    $validColors = @("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White")
    
    if ($Color -in $validColors) {
        Write-Host $Message -ForegroundColor $Color
    } else {
        Write-Host $Message
    }
    
    if ($script:logToFile) {
        Add-Content -Path $LogPath -Value $logMessage
    }
}

# Function to get process by name or ID
function Get-TargetProcess {
    if ($ProcessId -gt 0) {
        try {
            return Get-Process -Id $ProcessId -ErrorAction Stop
        } catch {
            Write-TraceOutput "Process with ID $ProcessId not found" "Red"
            return $null
        }
    } else {
        $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        if ($processes) {
            if ($processes.Count -gt 1) {
                Write-TraceOutput "Multiple processes found for '$ProcessName':" "Yellow"
                $processes | ForEach-Object { Write-TraceOutput "  PID: $($_.Id) - $($_.ProcessName)" "Yellow" }
                return $processes[0]  # Return first one
            }
            return $processes
        } else {
            Write-TraceOutput "Process '$ProcessName' not found" "Red"
            return $null
        }
    }
}

# Function to get detailed process information
function Get-ProcessDetails {
    param($Process)
    
    try {
        # Get performance counters
        $cpuCounter = Get-Counter "\Process($($Process.ProcessName))\% Processor Time" -MaxSamples 1 -ErrorAction SilentlyContinue
        $ioCounter = Get-Counter "\Process($($Process.ProcessName))\IO Data Bytes/sec" -MaxSamples 1 -ErrorAction SilentlyContinue
        
        $cpuUsage = if ($cpuCounter) { [math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2) } else { 0 }
        $ioUsage = if ($ioCounter) { [math]::Round($ioCounter.CounterSamples[0].CookedValue / 1KB, 2) } else { 0 }
        
        # Get memory info
        $workingSet = [math]::Round($Process.WorkingSet64 / 1MB, 2)
        $virtualMem = [math]::Round($Process.VirtualMemorySize64 / 1MB, 2)
        $privateMem = [math]::Round($Process.PrivateMemorySize64 / 1MB, 2)
        
        # Get thread info
        $threadCount = $Process.Threads.Count
        $handleCount = $Process.HandleCount
        
        # Calculate runtime
        $runtime = if ($Process.StartTime) { (Get-Date) - $Process.StartTime } else { New-TimeSpan }
        
        return [PSCustomObject]@{
            PID = $Process.Id
            ProcessName = $Process.ProcessName
            CPUPercent = $cpuUsage
            WorkingSetMB = $workingSet
            VirtualMemMB = $virtualMem
            PrivateMemMB = $privateMem
            IOKBPerSec = $ioUsage
            Threads = $threadCount
            Handles = $handleCount
            Status = $Process.Responding
            Priority = $Process.BasePriority
            Runtime = "$($runtime.Days)d $($runtime.Hours):$($runtime.Minutes.ToString('00')):$($runtime.Seconds.ToString('00'))"
            Path = try { $Process.MainModule.FileName } catch { "N/A" }
        }
    } catch {
        Write-TraceOutput "Error getting process details: $_" "Red"
        return $null
    }
}

# Function to get file handles (requires elevated privileges)
function Get-ProcessFileActivity {
    param($ProcessId)
    
    if (-not $script:showFiles) { return @() }
    
    try {
        $handles = @()
        $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($process) {
            $handles = @("File handles: $($process.HandleCount)")
            $handles += "  (File details require elevated privileges or external tools)"
        }
        return $handles
    } catch {
        return @("Error getting file activity: $_")
    }
}

# Function to get network connections
function Get-ProcessNetworkConnections {
    param($ProcessId)
    
    if (-not $script:showNetwork) { return @() }
    
    try {
        $connections = netstat -ano | Select-String "TCP|UDP" | ForEach-Object {
            $fields = $_.Line -split '\s+' | Where-Object { $_ -ne '' }
            if ($fields.Count -ge 5 -and $fields[-1] -eq $ProcessId) {
                [PSCustomObject]@{
                    Protocol = $fields[0]
                    LocalAddress = $fields[1]
                    ForeignAddress = $fields[2]
                    State = if ($fields[0] -eq "TCP") { $fields[3] } else { "N/A" }
                }
            }
        } | Where-Object { $_ -ne $null }
        
        $result = @()
        if ($connections) {
            $result += "Network Connections ($($connections.Count)):"
            $connections | ForEach-Object {
                $result += "  $($_.Protocol) $($_.LocalAddress) -> $($_.ForeignAddress) [$($_.State)]"
            }
        } else {
            $result += "No active network connections"
        }
        return $result
    } catch {
        return @("Error getting network connections: $_")
    }
}

# Function to get loaded modules
function Get-ProcessModules {
    param($Process)
    
    if (-not $script:showModules) { return @() }
    
    try {
        $modules = $Process.Modules | Select-Object -First 10
        $result = @()
        
        if ($modules) {
            $result += "Loaded Modules (top 10):"
            $modules | ForEach-Object {
                $sizeMB = [math]::Round($_.Size / 1MB, 2)
                $result += "  $($_.ModuleName) - ${sizeMB}MB"
            }
        } else {
            $result += "No module information available"
        }
        return $result
    } catch {
        return @("Error getting modules (may require elevated privileges): $_")
    }
}

# Function to handle keyboard input (CORRECTED)
function Get-KeyInput {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        
        switch ($key.Key) {
            'Q' { return 'quit' }
            'F' { 
                $script:showFiles = -not $script:showFiles
                Write-TraceOutput "File activity: $(if($script:showFiles){'ON'}else{'OFF'})" "Yellow"
                return 'continue'
            }
            'N' { 
                $script:showNetwork = -not $script:showNetwork
                Write-TraceOutput "Network connections: $(if($script:showNetwork){'ON'}else{'OFF'})" "Yellow"
                return 'continue'
            }
            'M' { 
                $script:showModules = -not $script:showModules
                Write-TraceOutput "Modules: $(if($script:showModules){'ON'}else{'OFF'})" "Yellow"
                return 'continue'
            }
        }
        
        # Handle + and - keys properly
        if ($key.KeyChar -eq '+' -or $key.Key -eq 'OemPlus') {
            $script:refreshInterval = [Math]::Max($script:refreshInterval - 1, 1)
            Write-TraceOutput "Refresh interval: $($script:refreshInterval)s" "Yellow"
            return 'continue'
        }
        
        if ($key.KeyChar -eq '-' -or $key.Key -eq 'OemMinus') {
            $script:refreshInterval = [Math]::Min($script:refreshInterval + 1, 30)
            Write-TraceOutput "Refresh interval: $($script:refreshInterval)s" "Yellow"
            return 'continue'
        }
    }
    return 'continue'
}

# Main monitoring loop
try {
    Write-TraceOutput "Starting process tracer..." "Green"
    Write-TraceOutput "Target: $ProcessName $(if($ProcessId -gt 0){"(PID: $ProcessId)"})" "Green"
    Write-TraceOutput "Press 'q' to quit, 'f' for files, 'n' for network, 'm' for modules" "Yellow"
    Write-TraceOutput ("-" * 80) "Gray"
    
    $iteration = 0
    
    while ($true) {
        $iteration++
        
        # Get target process
        $process = Get-TargetProcess
        if (-not $process) {
            Write-TraceOutput "Process not found, retrying in $($script:refreshInterval) seconds..." "Yellow"
            Start-Sleep -Seconds $script:refreshInterval
            continue
        }
        
        # Clear screen periodically to reduce clutter
        #if ($iteration % 15 -eq 1) {
        #    Clear-Host
        #}
       
        if ($iteration % 15 -eq 1 -or $iteration -eq 1) {
           if ($iteration -eq 1) {
              Clear-Host  # Only clear on first run
           } else {
              Set-CursorToTop  # Move cursor to top for subsequent updates
           }
        }

        Write-TraceOutput "`n=== Process Trace: $($process.ProcessName) (PID: $($process.Id)) - $(Get-Date -Format 'HH:mm:ss') ===" "Cyan"
        
        # Get detailed process information
        $details = Get-ProcessDetails -Process $process
        if ($details) {
            Write-TraceOutput "CPU: $($details.CPUPercent)% | Memory: $($details.WorkingSetMB)MB | I/O: $($details.IOKBPerSec) KB/s" "White"
            Write-TraceOutput "Threads: $($details.Threads) | Handles: $($details.Handles) | Runtime: $($details.Runtime)" "White"
            Write-TraceOutput "Path: $($details.Path)" "Gray"
            Write-TraceOutput "Priority: $($details.Priority) | Status: $(if($details.Status){'Responding'}else{'Not Responding'})" "White"
        }
        
        # Show additional info based on flags
        $fileActivity = Get-ProcessFileActivity -ProcessId $process.Id
        if ($fileActivity) {
            Write-TraceOutput "`nFile Activity:" "Green"
            $fileActivity | ForEach-Object { Write-TraceOutput $_ "White" }
        }
        
        $networkConnections = Get-ProcessNetworkConnections -ProcessId $process.Id
        if ($networkConnections) {
            Write-TraceOutput "`nNetwork Activity:" "Green"
            $networkConnections | ForEach-Object { Write-TraceOutput $_ "White" }
        }
        
        $modules = Get-ProcessModules -Process $process
        if ($modules) {
            Write-TraceOutput "`nModules:" "Green"
            $modules | ForEach-Object { Write-TraceOutput $_ "White" }
        }
        
        Write-TraceOutput "`n" + ("-" * 80) "Gray"
        
        # Wait for refresh interval or key press
        $startTime = Get-Date
        do {
            Start-Sleep -Milliseconds 100
            $keyResult = Get-KeyInput
            
            if ($keyResult -eq 'quit') {
                throw "User quit"
            }
            
        } while (((Get-Date) - $startTime).TotalSeconds -lt $script:refreshInterval)
    }
}
catch {
    if ($_.Exception.Message -ne "User quit") {
        Write-TraceOutput "Error: $_" "Red"
    }
}
finally {
    Write-TraceOutput "`nProcess tracer terminated." "Green"
}