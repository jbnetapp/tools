# Simple high-performance log file writer
param(
    [string]$LogPath = "C:\Temp\TestLogs",
    [int]$ThreadCount = 8,
    [int]$FilesPerThread = 1000,
    [int]$WritesPerFile = 100,
    [int]$DataSizeKB = 4,
    [int]$DurationMinutes = 5
)

# Create log directory
if (!(Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force
}

Write-Host "Starting high-performance I/O test..." -ForegroundColor Green
Write-Host "Threads: $ThreadCount" -ForegroundColor Yellow
Write-Host "Files per thread: $FilesPerThread" -ForegroundColor Yellow
Write-Host "Writes per file: $WritesPerFile" -ForegroundColor Yellow
Write-Host "Data size: $DataSizeKB KB" -ForegroundColor Yellow

# Generate test data
$testData = "A" * ($DataSizeKB * 1024)
$startTime = Get-Date

# Script block for parallel execution
$scriptBlock = {
    param($LogPath, $ThreadId, $FilesPerThread, $WritesPerFile, $TestData, $StartTime, $DurationMinutes)
    
    $filesCreated = 0
    $bytesWritten = 0
    $endTime = $StartTime.AddMinutes($DurationMinutes)
    
    for ($fileNum = 1; $fileNum -le $FilesPerThread; $fileNum++) {
        if ((Get-Date) -gt $endTime) { break }
        
        $fileName = Join-Path $LogPath "thread_$ThreadId`_file_$fileNum`_$(Get-Date -Format 'yyyyMMddHHmmss').log"
        
        try {
            # Create file with high-performance settings
            $fileStream = [System.IO.File]::Create($fileName, 65536, [System.IO.FileOptions]::SequentialScan)
            $writer = New-Object System.IO.StreamWriter($fileStream, [System.Text.Encoding]::UTF8, 65536)
            
            for ($writeNum = 1; $writeNum -le $WritesPerFile; $writeNum++) {
                $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') [THREAD-$ThreadId] [FILE-$fileNum] [WRITE-$writeNum] $TestData"
                $writer.WriteLine($logEntry)
                $bytesWritten += $logEntry.Length + 2 # +2 for CRLF
            }
            
            $writer.Close()
            $fileStream.Close()
            $filesCreated++
            
            # Optional: Simulate random file operations
            if ($fileNum % 10 -eq 0) {
                # Simulate log rotation - compress old file
                # Remove-Item $fileName -Force
            }
        }
        catch {
            Write-Host "Thread $ThreadId Error: $_" -ForegroundColor Red
        }
    }
    
    return @{
        ThreadId = $ThreadId
        FilesCreated = $filesCreated
        BytesWritten = $bytesWritten
        Duration = (Get-Date) - $StartTime
    }
}

# Start parallel jobs
Write-Host "Starting $ThreadCount parallel threads..." -ForegroundColor Green
$jobs = 1..$ThreadCount | ForEach-Object {
    Start-Job -ScriptBlock $scriptBlock -ArgumentList $LogPath, $_, $FilesPerThread, $WritesPerFile, $testData, $startTime, $DurationMinutes
}

# Monitor progress
while ($jobs | Where-Object { $_.State -eq 'Running' }) {
    $completed = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
    $running = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
    
    Write-Host "`rProgress: $completed completed, $running running..." -NoNewline -ForegroundColor Cyan
    Start-Sleep -Seconds 1
}

Write-Host "`nAll threads completed. Collecting results..." -ForegroundColor Green

# Collect results
$results = $jobs | Receive-Job
$jobs | Remove-Job

# Calculate statistics
$totalFiles = ($results | Measure-Object FilesCreated -Sum).Sum
$totalBytes = ($results | Measure-Object BytesWritten -Sum).Sum
$totalDuration = (Get-Date) - $startTime
$throughputMBps = [math]::Round(($totalBytes / 1MB) / $totalDuration.TotalSeconds, 2)
$filesPerSecond = [math]::Round($totalFiles / $totalDuration.TotalSeconds, 2)

Write-Host "`n=== Performance Results ===" -ForegroundColor Green
Write-Host "Total Files Created: $totalFiles" -ForegroundColor Yellow
Write-Host "Total Bytes Written: $([math]::Round($totalBytes / 1MB, 2)) MB" -ForegroundColor Yellow
Write-Host "Total Duration: $($totalDuration.TotalSeconds) seconds" -ForegroundColor Yellow
Write-Host "Throughput: $throughputMBps MB/s" -ForegroundColor Yellow
Write-Host "Files per second: $filesPerSecond" -ForegroundColor Yellow