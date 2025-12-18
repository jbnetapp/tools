param(
    [Parameter(Mandatory=$true)]
    [string]$ProcessName
)

<#
.SYNOPSIS
    Gets TCP connection status for all processes with the specified name.

.DESCRIPTION
    This script takes a process name as input and displays all TCP connections
    for processes matching that name, including connection state, local and remote endpoints.

.PARAMETER ProcessName
    The name of the process to analyze (without .exe extension)

.EXAMPLE
    .\Get-ProcessTcpConnections.ps1 -ProcessName "chrome"
    .\Get-ProcessTcpConnections.ps1 "notepad"
#>

try {
    # Get all processes with the specified name
    $processes = Get-Process -Name $ProcessName -ErrorAction Stop
    
    if ($processes.Count -eq 0) {
        Write-Warning "No processes found with name '$ProcessName'"
        return
    }

    # Get all process IDs for the specified process name
    $processIds = $processes | Select-Object -ExpandProperty Id
    
    Write-Host "Found $($processes.Count) process(es) with name '$ProcessName'" -ForegroundColor Green
    Write-Host "Process IDs: $($processIds -join ',')" -ForegroundColor Gray
    Write-Host ""

    # Get TCP connections for all matching process IDs
    Get-NetTCPConnection -OwningProcess $processIds -ErrorAction SilentlyContinue

} catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
    Write-Error "Process '$ProcessName' not found. Please check the process name and try again."
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}