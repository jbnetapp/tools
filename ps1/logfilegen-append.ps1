# Compatible with Windows PowerShell 5.1 using Start-Job
param(
    [string]$LogPath = "C:\Temp\TestLogs",
    [int]$ThreadCount = 8,
    [int]$TotalWrites = 10000,
    [int]$WriteSize = 128,  # Size in bytes for each write operation
    [int]$DurationMinutes = 5,
    [int]$BatchSize = 100,  # Number of writes before flushing
    [string]$CharacterSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,.<>?",
    [switch]$UseRealisticData,
    [switch]$SyncAfterBatch  # Force sync to disk after each batch
)

# Check PowerShell version
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan

# Create log directory
if (!(Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force
}

Write-Host "Starting high-performance I/O test with append operations..." -ForegroundColor Green
Write-Host "Threads: $ThreadCount" -ForegroundColor Yellow
Write-Host "Total writes per thread: $TotalWrites" -ForegroundColor Yellow
Write-Host "Write size: $WriteSize bytes" -ForegroundColor Yellow
Write-Host "Batch size: $BatchSize writes before flush" -ForegroundColor Yellow
Write-Host "Sync after batch: $(if($SyncAfterBatch){'Enabled'}else{'Disabled'})" -ForegroundColor Yellow
Write-Host "Character generation: $(if($UseRealisticData){'Realistic log data'}else{'Random characters'})" -ForegroundColor Yellow

# Generate realistic log data templates if requested
$logTemplates = @()
$sampleUsers = @("john.doe", "jane.smith", "admin", "system", "api_user", "service_account", "guest")
$sampleActions = @("login", "logout", "create", "update", "delete", "search", "export", "backup", "restore")
$sampleModules = @("AuthService", "OrderProcessor", "PaymentGateway", "UserManager", "ReportGenerator", "APIController")
$sampleIPs = @("192.168.1.100", "10.0.0.15", "172.16.0.50", "203.0.113.25", "198.51.100.10")
$logLevels = @("DEBUG", "INFO", "WARN", "ERROR", "TRACE")

if ($UseRealisticData) {
    $logTemplates = @(
        "User '{0}' performed action '{1}' on module '{2}' from IP {3}",
        "Processing request ID {4} for user '{0}' - Status: {5}",
        "Database query executed in {6}ms for module '{2}'",
        "Cache hit/miss for key '{7}' - Module: '{2}'",
        "API endpoint '{8}' called by user '{0}' - Response time: {6}ms",
        "Session {9} created for user '{0}' from IP {3}",
        "File operation '{1}' completed - Size: {10}KB - Duration: {6}ms"
    )
}

$startTime = Get-Date

# Script block for parallel execution (Windows PowerShell 5.1 compatible)
$scriptBlock = {
    param($LogPath, $ThreadId, $TotalWrites, $WriteSize, $StartTime, $DurationMinutes, $CharacterSet, $UseRealisticData, $LogTemplates, $SampleUsers, $SampleActions, $SampleModules, $SampleIPs, $LogLevels, $BatchSize, $SyncAfterBatch)
    
    $writesCompleted = 0
    $bytesWritten = 0
    $endTime = $StartTime.AddMinutes($DurationMinutes)
    $flushCount = 0
    $syncCount = 0
    
    # Initialize random number generator for this thread
    $random = New-Object System.Random([System.Threading.Thread]::CurrentThread.ManagedThreadId + (Get-Date).Millisecond)
    
    # Single log file per thread
    $fileName = Join-Path $LogPath "thread_$ThreadId`_$(Get-Date -Format 'yyyyMMddHHmmss').log"
    
    # Function to generate random string within script block
    function Get-ThreadRandomString {
        param([int]$Length, [string]$Characters, [System.Random]$RandomGen)
        
        if ($Length -le 0) { return "" }
        
        $result = ""
        for ($i = 0; $i -lt $Length; $i++) {
            $result += $Characters[$RandomGen.Next(0, $Characters.Length)]
        }
        return $result
    }
    
    # Function to generate realistic log entry
    function Get-RealisticLogEntry {
        param([System.Random]$RandomGen, $Templates, $Users, $Actions, $Modules, $IPs, $Levels, [int]$TargetSize)
        
        $template = $Templates[$RandomGen.Next(0, $Templates.Count)]
        $user = $Users[$RandomGen.Next(0, $Users.Count)]
        $action = $Actions[$RandomGen.Next(0, $Actions.Count)]
        $module = $Modules[$RandomGen.Next(0, $Modules.Count)]
        $ip = $IPs[$RandomGen.Next(0, $IPs.Count)]
        $level = $Levels[$RandomGen.Next(0, $Levels.Count)]
        $requestId = $RandomGen.Next(10000, 99999)
        $status = @("SUCCESS", "FAILED", "PENDING", "TIMEOUT")[$RandomGen.Next(0, 4)]
        $duration = $RandomGen.Next(10, 5000)
        $cacheKey = "cache_key_" + $RandomGen.Next(1000, 9999)
        $endpoint = "/api/v1/" + $action
        $sessionId = "sess_" + $RandomGen.Next(100000, 999999)
        $fileSize = $RandomGen.Next(1, 10240)
        
        $baseEntry = "[$level] " + ($template -f $user, $action, $module, $ip, $requestId, $status, $duration, $cacheKey, $endpoint, $sessionId, $fileSize)
        
        # Pad to target size if needed
        if ($baseEntry.Length -lt $TargetSize) {
            $paddingNeeded = $TargetSize - $baseEntry.Length - 10  # Leave some room
            if ($paddingNeeded -gt 0) {
                $padding = Get-ThreadRandomString -Length $paddingNeeded -Characters "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" -RandomGen $RandomGen
                $baseEntry += " DATA:$padding"
            }
        }
        
        return $baseEntry.Substring(0, [Math]::Min($baseEntry.Length, $TargetSize))
    }
    
    try {
        # Create file with append mode - using FileStream for better control
        $fileStream = New-Object System.IO.FileStream($fileName, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read, 65536, [System.IO.FileOptions]::SequentialScan)
        $writer = New-Object System.IO.StreamWriter($fileStream, [System.Text.Encoding]::UTF8, 65536)
        
        # Perform many small writes
        for ($writeNum = 1; $writeNum -le $TotalWrites; $writeNum++) {
            if ((Get-Date) -gt $endTime) { break }
            
            if ($UseRealisticData) {
                # Generate realistic log entry with target size
                $targetContentSize = $WriteSize - 50  # Leave room for timestamp and metadata
                $dataContent = Get-RealisticLogEntry -RandomGen $random -Templates $LogTemplates -Users $SampleUsers -Actions $SampleActions -Modules $SampleModules -IPs $SampleIPs -Levels $LogLevels -TargetSize $targetContentSize
            } else {
                # Generate random character data
                $targetContentSize = $WriteSize - 50  # Leave room for timestamp and metadata
                if ($targetContentSize -gt 0) {
                    $dataContent = Get-ThreadRandomString -Length $targetContentSize -Characters $CharacterSet -RandomGen $random
                } else {
                    $dataContent = "DATA"
                }
            }
            
            # Create log entry with timestamp
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
            $logEntry = "$timestamp [T$ThreadId] [W$writeNum] $dataContent"
            
            # Ensure we don't exceed target size
            if ($logEntry.Length -gt $WriteSize) {
                $logEntry = $logEntry.Substring(0, $WriteSize - 2) + ".."
            }
            
            # Write to file
            $writer.WriteLine($logEntry)
            $bytesWritten += $logEntry.Length + 2 # +2 for CRLF
            $writesCompleted++
            
            # Flush every BatchSize writes for better performance/reliability balance
            if ($writeNum % $BatchSize -eq 0) {
                $writer.Flush()
                $flushCount++
                
                # Optional: Force sync to disk
                if ($SyncAfterBatch) {
                    $fileStream.Flush($true)  # Force OS to write to disk
                    $syncCount++
                }
            }
        }
        
        # Final flush and sync
        $writer.Flush()
        $fileStream.Flush($true)
        $writer.Dispose()
        $fileStream.Dispose()
        
    }
    catch {
        Write-Error "Thread $ThreadId Error: $_"
        if ($writer) { $writer.Dispose() }
        if ($fileStream) { $fileStream.Dispose() }
    }
    
    # Return structured object
    return [PSCustomObject]@{
        ThreadId = $ThreadId
        WritesCompleted = $writesCompleted
        BytesWritten = $bytesWritten
        FlushCount = $flushCount
        SyncCount = $syncCount
        FileName = $fileName
        Duration = (Get-Date) - $StartTime
    }
}

# Start parallel jobs
Write-Host "Starting $ThreadCount parallel threads..." -ForegroundColor Green
$jobs = 1..$ThreadCount | ForEach-Object {
    Start-Job -ScriptBlock $scriptBlock -ArgumentList $LogPath, $_, $TotalWrites, $WriteSize, $startTime, $DurationMinutes, $CharacterSet, $UseRealisticData.IsPresent, $logTemplates, $sampleUsers, $sampleActions, $sampleModules, $sampleIPs, $logLevels, $BatchSize, $SyncAfterBatch.IsPresent
}

# Monitor progress with better feedback
$totalJobs = $jobs.Count
while ($jobs | Where-Object { $_.State -eq 'Running' }) {
    $completed = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
    $running = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
    $failed = ($jobs | Where-Object { $_.State -eq 'Failed' }).Count
    
    $elapsed = ((Get-Date) - $startTime).TotalSeconds
    
    # Show current file system stats
    if (Test-Path $LogPath) {
        $currentFiles = (Get-ChildItem $LogPath -Filter "*.log" -ErrorAction SilentlyContinue | Measure-Object).Count
        $currentSize = (Get-ChildItem $LogPath -Filter "*.log" -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $currentSizeMB = [math]::Round($currentSize / 1MB, 2)
        
        # Estimate writes per second based on current progress
        $estimatedWrites = 0
        if ($elapsed -gt 0) {
            # Rough estimate based on file sizes (assuming average write size)
            $estimatedWrites = [math]::Round($currentSize / $WriteSize / $elapsed, 0)
        }
        
        Write-Host "`r[$([math]::Round($elapsed, 0))s] Jobs: $completed/$totalJobs completed, $running running | Files: $currentFiles | Size: $currentSizeMB MB | Est. Writes/s: $estimatedWrites" -NoNewline -ForegroundColor Cyan
    } else {
        Write-Host "`r[$([math]::Round($elapsed, 0))s] Progress: $completed/$totalJobs completed, $running running, $failed failed" -NoNewline -ForegroundColor Cyan
    }
    
    Start-Sleep -Seconds 2
}

Write-Host "`nAll threads completed. Collecting results..." -ForegroundColor Green

# Wait for all jobs to complete and collect results
$jobs | Wait-Job | Out-Null

# Check for failed jobs
$failedJobs = $jobs | Where-Object { $_.State -eq 'Failed' }
if ($failedJobs) {
    Write-Host "Warning: $($failedJobs.Count) jobs failed!" -ForegroundColor Red
    $failedJobs | ForEach-Object {
        Write-Host "Failed Job $($_.Id): $($_.JobStateInfo.Reason)" -ForegroundColor Red
    }
}

# Receive results from completed jobs
$completedJobs = $jobs | Where-Object { $_.State -eq 'Completed' }
$results = $completedJobs | Receive-Job

# Clean up jobs
$jobs | Remove-Job -Force

# Validate results
if (-not $results -or $results.Count -eq 0) {
    Write-Host "No results received from background jobs!" -ForegroundColor Red
    Write-Host "Checking log directory for actual files created..." -ForegroundColor Yellow
    
    if (Test-Path $LogPath) {
        $actualFiles = Get-ChildItem $LogPath -Filter "*.log" | Measure-Object
        $totalSize = Get-ChildItem $LogPath -Filter "*.log" | Measure-Object -Property Length -Sum
        Write-Host "Files found in directory: $($actualFiles.Count)" -ForegroundColor Yellow
        Write-Host "Total size: $([math]::Round($totalSize.Sum / 1MB, 2)) MB" -ForegroundColor Yellow
    }
    return
}

# Calculate statistics
try {
    $totalWrites = ($results | Measure-Object WritesCompleted -Sum).Sum
    $totalBytes = ($results | Measure-Object BytesWritten -Sum).Sum
    $totalFlushes = ($results | Measure-Object FlushCount -Sum).Sum
    $totalSyncs = ($results | Measure-Object SyncCount -Sum).Sum
    $totalDuration = (Get-Date) - $startTime
    
    if ($totalDuration.TotalSeconds -gt 0) {
        $throughputMBps = [math]::Round(($totalBytes / 1MB) / $totalDuration.TotalSeconds, 2)
        $writesPerSecond = [math]::Round($totalWrites / $totalDuration.TotalSeconds, 2)
        $avgWriteSize = [math]::Round($totalBytes / $totalWrites, 2)
    } else {
        $throughputMBps = 0
        $writesPerSecond = 0
        $avgWriteSize = 0
    }

    Write-Host "`n=== Performance Results ===" -ForegroundColor Green
    Write-Host "Total Writes Completed: $totalWrites" -ForegroundColor Yellow
    Write-Host "Total Bytes Written: $([math]::Round($totalBytes / 1MB, 2)) MB" -ForegroundColor Yellow
    Write-Host "Average Write Size: $avgWriteSize bytes" -ForegroundColor Yellow
    Write-Host "Total Duration: $([math]::Round($totalDuration.TotalSeconds, 2)) seconds" -ForegroundColor Yellow
    Write-Host "Throughput: $throughputMBps MB/s" -ForegroundColor Yellow
    Write-Host "Writes per second: $writesPerSecond" -ForegroundColor Yellow
    Write-Host "Total Flushes: $totalFlushes" -ForegroundColor Yellow
    Write-Host "Total Syncs: $totalSyncs" -ForegroundColor Yellow
    
    # Show per-thread breakdown
    Write-Host "`n=== Per-Thread Results ===" -ForegroundColor Green
    $results | Sort-Object ThreadId | ForEach-Object {
        $threadWritesPerSec = if ($_.Duration.TotalSeconds -gt 0) { [math]::Round($_.WritesCompleted / $_.Duration.TotalSeconds, 2) } else { 0 }
        Write-Host "Thread $($_.ThreadId): $($_.WritesCompleted) writes, $([math]::Round($_.BytesWritten / 1MB, 2)) MB, $threadWritesPerSec writes/s, Flushes: $($_.FlushCount)" -ForegroundColor Cyan
    }
    
    # Verify with actual file system
    Write-Host "`n=== File System Verification ===" -ForegroundColor Green
    if (Test-Path $LogPath) {
        $actualFiles = Get-ChildItem $LogPath -Filter "*.log"
        $actualCount = $actualFiles.Count
        $actualSize = ($actualFiles | Measure-Object -Property Length -Sum).Sum
        
        Write-Host "Actual files on disk: $actualCount" -ForegroundColor $(if($actualCount -eq $ThreadCount){'Green'}else{'Yellow'})
        Write-Host "Actual size on disk: $([math]::Round($actualSize / 1MB, 2)) MB" -ForegroundColor $(if([math]::Abs($actualSize - $totalBytes) -lt 1MB){'Green'}else{'Yellow'})
        
        # Show file details
        Write-Host "`n=== File Details ===" -ForegroundColor Green
        $actualFiles | Sort-Object Name | ForEach-Object {
            $lineCount = (Get-Content $_.FullName | Measure-Object).Count
            Write-Host "$($_.Name): $([math]::Round($_.Length / 1KB, 2)) KB, $lineCount lines" -ForegroundColor Cyan
        }
    }
} catch {
    Write-Host "Error calculating statistics: $_" -ForegroundColor Red
}