# Compatible with Windows PowerShell 5.1 using Start-Job
param(
    [string]$LogPath = "C:\Temp\TestLogs",
    [int]$ThreadCount = 8,
    [int]$FilesPerThread = 1000,
    [int]$WritesPerFile = 100,
    [int]$DataSizeKB = 4,
    [int]$DurationMinutes = 5,
    [string]$CharacterSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,.<>?",
    [switch]$UseRealisticData
)

# Check PowerShell version
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan

# Create log directory
if (!(Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force
}

Write-Host "Starting high-performance I/O test..." -ForegroundColor Green
Write-Host "LogPath: $LogPath" -ForegroundColor Yellow
Write-Host "Threads: $ThreadCount" -ForegroundColor Yellow
Write-Host "Files per thread: $FilesPerThread" -ForegroundColor Yellow
Write-Host "Writes per file: $WritesPerFile" -ForegroundColor Yellow
Write-Host "Data size: $DataSizeKB KB" -ForegroundColor Yellow
Write-Host "Character generation: $(if($UseRealisticData){'Realistic log data'}else{'Random characters'})" -ForegroundColor Yellow

# Function to generate random string
function Get-RandomString {
    param(
        [int]$Length,
        [string]$Characters
    )
    
    $randomString = ""
    $random = New-Object System.Random
    
    for ($i = 0; $i -lt $Length; $i++) {
        $randomString += $Characters[$random.Next(0, $Characters.Length)]
    }
    
    return $randomString
}

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
    param($LogPath, $ThreadId, $FilesPerThread, $WritesPerFile, $DataSizeKB, $StartTime, $DurationMinutes, $CharacterSet, $UseRealisticData, $LogTemplates, $SampleUsers, $SampleActions, $SampleModules, $SampleIPs, $LogLevels)
    
    $filesCreated = 0
    $bytesWritten = 0
    $endTime = $StartTime.AddMinutes($DurationMinutes)
    
    # Initialize random number generator for this thread
    $random = New-Object System.Random([System.Threading.Thread]::CurrentThread.ManagedThreadId + (Get-Date).Millisecond)
    
    # Function to generate random string within script block
    function Get-ThreadRandomString {
        param([int]$Length, [string]$Characters, [System.Random]$RandomGen)
        
        $result = ""
        for ($i = 0; $i -lt $Length; $i++) {
            $result += $Characters[$RandomGen.Next(0, $Characters.Length)]
        }
        return $result
    }
    
    # Function to generate realistic log entry
    function Get-RealisticLogEntry {
        param([System.Random]$RandomGen, $Templates, $Users, $Actions, $Modules, $IPs, $Levels)
        
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
        
        return "[$level] " + ($template -f $user, $action, $module, $ip, $requestId, $status, $duration, $cacheKey, $endpoint, $sessionId, $fileSize)
    }
    
    for ($fileNum = 1; $fileNum -le $FilesPerThread; $fileNum++) {
        if ((Get-Date) -gt $endTime) { break }
        
        $fileName = Join-Path $LogPath "thread_$ThreadId`_file_$fileNum`_$(Get-Date -Format 'yyyyMMddHHmmss').log"
        
        try {
            # Create file with high-performance settings
            $fileStream = [System.IO.File]::Create($fileName, 65536, [System.IO.FileOptions]::SequentialScan)
            $writer = New-Object System.IO.StreamWriter($fileStream, [System.Text.Encoding]::UTF8, 65536)
            
            for ($writeNum = 1; $writeNum -le $WritesPerFile; $writeNum++) {
                if ($UseRealisticData) {
                    # Generate realistic log entry
                    $dataContent = Get-RealisticLogEntry -RandomGen $random -Templates $LogTemplates -Users $SampleUsers -Actions $SampleActions -Modules $SampleModules -IPs $SampleIPs -Levels $LogLevels
                    
                    # Pad or truncate to approximate target size
                    $targetLength = ($DataSizeKB * 1024) - 100  # Leave room for timestamp and metadata
                    if ($dataContent.Length -lt $targetLength) {
                        $padding = Get-ThreadRandomString -Length ($targetLength - $dataContent.Length) -Characters $CharacterSet -RandomGen $random
                        $dataContent += " PADDING: $padding"
                    } elseif ($dataContent.Length -gt $targetLength) {
                        $dataContent = $dataContent.Substring(0, $targetLength)
                    }
                } else {
                    # Generate random character data
                    $dataContent = Get-ThreadRandomString -Length ($DataSizeKB * 1024) -Characters $CharacterSet -RandomGen $random
                }
                
                $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') [THREAD-$ThreadId] [FILE-$fileNum] [WRITE-$writeNum] $dataContent"
                $writer.WriteLine($logEntry)
                $bytesWritten += $logEntry.Length + 2 # +2 for CRLF
            }
            
            $writer.Dispose()
            $fileStream.Dispose()
            $filesCreated++
        }
        catch {
            Write-Error "Thread $ThreadId Error: $_"
        }
    }
    
    # Return structured object
    return [PSCustomObject]@{
        ThreadId = $ThreadId
        FilesCreated = $filesCreated
        BytesWritten = $bytesWritten
        Duration = (Get-Date) - $StartTime
    }
}

# Start parallel jobs
Write-Host "Starting $ThreadCount parallel threads..." -ForegroundColor Green
$jobs = 1..$ThreadCount | ForEach-Object {
    Start-Job -ScriptBlock $scriptBlock -ArgumentList $LogPath, $_, $FilesPerThread, $WritesPerFile, $DataSizeKB, $startTime, $DurationMinutes, $CharacterSet, $UseRealisticData.IsPresent, $logTemplates, $sampleUsers, $sampleActions, $sampleModules, $sampleIPs, $logLevels
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
        
        Write-Host "`r[$([math]::Round($elapsed, 0))s] Jobs: $completed/$totalJobs completed, $running running, $failed failed | Files: $currentFiles | Size: $currentSizeMB MB" -NoNewline -ForegroundColor Cyan
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
    $totalFiles = ($results | Measure-Object FilesCreated -Sum).Sum
    $totalBytes = ($results | Measure-Object BytesWritten -Sum).Sum
    $totalDuration = (Get-Date) - $startTime
    
    if ($totalDuration.TotalSeconds -gt 0) {
        $throughputMBps = [math]::Round(($totalBytes / 1MB) / $totalDuration.TotalSeconds, 2)
        $filesPerSecond = [math]::Round($totalFiles / $totalDuration.TotalSeconds, 2)
    } else {
        $throughputMBps = 0
        $filesPerSecond = 0
    }

    Write-Host "`n=== Performance Results ===" -ForegroundColor Green
    Write-Host "Total Files Created: $totalFiles" -ForegroundColor Yellow
    Write-Host "Total Bytes Written: $([math]::Round($totalBytes / 1MB, 2)) MB" -ForegroundColor Yellow
    Write-Host "Total Duration: $([math]::Round($totalDuration.TotalSeconds, 2)) seconds" -ForegroundColor Yellow
    Write-Host "Throughput: $throughputMBps MB/s" -ForegroundColor Yellow
    Write-Host "Files per second: $filesPerSecond" -ForegroundColor Yellow
    
    # Show per-thread breakdown
    Write-Host "`n=== Per-Thread Results ===" -ForegroundColor Green
    $results | Sort-Object ThreadId | ForEach-Object {
        Write-Host "Thread $($_.ThreadId): $($_.FilesCreated) files, $([math]::Round($_.BytesWritten / 1MB, 2)) MB, Duration: $([math]::Round($_.Duration.TotalSeconds, 2))s" -ForegroundColor Cyan
    }
    
    # Verify with actual file system
    Write-Host "`n=== File System Verification ===" -ForegroundColor Green
    if (Test-Path $LogPath) {
        $actualFiles = Get-ChildItem $LogPath -Filter "*.log"
        $actualCount = $actualFiles.Count
        $actualSize = ($actualFiles | Measure-Object -Property Length -Sum).Sum
        
        Write-Host "Actual files on disk: $actualCount" -ForegroundColor $(if($actualCount -eq $totalFiles){'Green'}else{'Yellow'})
        Write-Host "Actual size on disk: $([math]::Round($actualSize / 1MB, 2)) MB" -ForegroundColor $(if([math]::Abs($actualSize - $totalBytes) -lt 1MB){'Green'}else{'Yellow'})
        
        if ($actualCount -ne $totalFiles) {
            Write-Host "Warning: File count mismatch!" -ForegroundColor Yellow
        }
        
        # Show sample of generated content
        #Write-Host "`n=== Sample Content ===" -ForegroundColor Green
        #if ($actualFiles.Count -gt 0) {
        #    $sampleFile = $actualFiles[0]
        #    $sampleContent = Get-Content $sampleFile.FullName -TotalCount 3
        #    Write-Host "Sample from $($sampleFile.Name):" -ForegroundColor Cyan
        #    $sampleContent | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        #}
    }
} catch {
    Write-Host "Error calculating statistics: $_" -ForegroundColor Red
}