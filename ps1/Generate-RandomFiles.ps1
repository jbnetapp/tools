param(
    [Parameter(Mandatory=$true)]
    [int]$NumberOfFiles,
    
    [Parameter(Mandatory=$true)]
    [long]$MinFileSize,
    
    [Parameter(Mandatory=$true)]
    [long]$MaxFileSize,
    
    [string]$OutputDirectory = ".\RandomFiles",
    
    [int]$ThreadCount = [Environment]::ProcessorCount
)

# Validate parameters
if ($MinFileSize -le 0 -or $MaxFileSize -le 0) {
    Write-Error "File sizes must be positive values"
    exit 1
}

if ($MinFileSize -gt $MaxFileSize) {
    Write-Error "Minimum file size cannot be greater than maximum file size"
    exit 1
}

if ($NumberOfFiles -le 0) {
    Write-Error "Number of files must be positive"
    exit 1
}

# Create output directory if it doesn't exist
if (!(Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    Write-Host "Created directory: $OutputDirectory" -ForegroundColor Green
}

# Get absolute path
$OutputDirectory = Resolve-Path $OutputDirectory

Write-Host "Generating $NumberOfFiles random files..." -ForegroundColor Cyan
Write-Host "File size range: $MinFileSize - $MaxFileSize bytes" -ForegroundColor Cyan
Write-Host "Output directory: $OutputDirectory" -ForegroundColor Cyan
Write-Host "Using $ThreadCount threads for parallel processing" -ForegroundColor Cyan

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Script block for parallel execution
$scriptBlock = {
    param($FileIndex, $MinSize, $MaxSize, $OutputDir)
    
    # Generate random file size
    $random = New-Object System.Random
    $fileSize = $random.Next($MinSize, $MaxSize + 1)
    
    # Generate unique filename with timestamp and random component
    $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $randomSuffix = $random.Next(1000, 9999)
    $fileName = "RandomFile_${FileIndex}_${timestamp}_${randomSuffix}.dat"
    $filePath = Join-Path $OutputDir $fileName
    
    try {
        # Use .NET FileStream for optimal performance
        $fileStream = [System.IO.File]::Create($filePath)
        
        if ($fileSize -gt 0) {
            # Generate random data in chunks for better memory efficiency
            $chunkSize = [Math]::Min($fileSize, 1MB)
            $buffer = New-Object byte[] $chunkSize
            $remainingBytes = $fileSize
            
            while ($remainingBytes -gt 0) {
                $bytesToWrite = [Math]::Min($remainingBytes, $chunkSize)
                $random.NextBytes($buffer)
                $fileStream.Write($buffer, 0, $bytesToWrite)
                $remainingBytes -= $bytesToWrite
            }
        }
        
        $fileStream.Close()
        $fileStream.Dispose()
        
        return @{
            Success = $true
            FileName = $fileName
            FileSize = $fileSize
        }
    }
    catch {
        if ($fileStream) {
            $fileStream.Close()
            $fileStream.Dispose()
        }
        return @{
            Success = $false
            FileName = $fileName
            Error = $_.Exception.Message
        }
    }
}

# Execute in parallel using runspaces for maximum performance
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $ThreadCount)
$runspacePool.Open()

$jobs = @()
for ($i = 1; $i -le $NumberOfFiles; $i++) {
    $powershell = [powershell]::Create()
    $powershell.RunspacePool = $runspacePool
    
    [void]$powershell.AddScript($scriptBlock)
    [void]$powershell.AddArgument($i)
    [void]$powershell.AddArgument($MinFileSize)
    [void]$powershell.AddArgument($MaxFileSize)
    [void]$powershell.AddArgument($OutputDirectory)
    
    $jobs += @{
        PowerShell = $powershell
        Handle = $powershell.BeginInvoke()
    }
}

# Collect results and show progress
$completed = 0
$successful = 0
$failed = 0
$totalSize = 0

Write-Host "`nProgress:" -ForegroundColor Yellow

foreach ($job in $jobs) {
    $result = $job.PowerShell.EndInvoke($job.Handle)
    $job.PowerShell.Dispose()
    
    $completed++
    $progressPercent = [math]::Round(($completed / $NumberOfFiles) * 100, 1)
    
    if ($result.Success) {
        $successful++
        $totalSize += $result.FileSize
        Write-Progress -Activity "Generating Files" -Status "Created $($result.FileName)" -PercentComplete $progressPercent
    } else {
        $failed++
        Write-Warning "Failed to create $($result.FileName): $($result.Error)"
    }
}

Write-Progress -Activity "Generating Files" -Completed

$runspacePool.Close()
$runspacePool.Dispose()

$stopwatch.Stop()

# Display results
Write-Host "`n" + "="*60 -ForegroundColor Green
Write-Host "FILE GENERATION COMPLETED" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Green
Write-Host "Total files requested: $NumberOfFiles" -ForegroundColor White
Write-Host "Successfully created: $successful" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "Total data generated: $([math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor Cyan
Write-Host "Execution time: $($stopwatch.Elapsed.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Cyan
Write-Host "Average file generation rate: $([math]::Round($successful / $stopwatch.Elapsed.TotalSeconds, 1)) files/second" -ForegroundColor Cyan
Write-Host "Output directory: $OutputDirectory" -ForegroundColor White
Write-Host "="*60 -ForegroundColor Green

if ($failed -gt 0) {
    exit 1
}
