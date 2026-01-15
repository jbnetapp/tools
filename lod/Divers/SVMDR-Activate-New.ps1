<#
.SYNOPSIS
    Activates SVM Disaster Recovery by stopping the source SVM and activating the destination.

.DESCRIPTION
    This script performs the following operations:
    1. Connects to the source cluster (cluster1) and stops the SVM with CIFS modifications
    2. Connects to the destination cluster (cluster2) and activates the SVM with SnapMirror operations
    3. Updates the DNS record with the new IP address

.PARAMETER cluster1Name
    The name or IP address of the source cluster

.PARAMETER cluster2Name
    The name or IP address of the destination cluster

.PARAMETER svmName
    The name of the Storage Virtual Machine (SVM)

.PARAMETER cifsName
    The new CIFS server name to use on the destination

.PARAMETER cifsNameOld
    The old CIFS server name on the source

.PARAMETER SVMNewIP
    The new IP address for the SVM to be updated in DNS

.EXAMPLE
    .\SVMDR-Activate-New.ps1 -cluster1Name "cluster1.domain.com" -cluster2Name "cluster2.domain.com" `
        -svmName "svm01" -cifsName "CIFS01" -cifsNameOld "CIFS01-OLD" -SVMNewIP "192.168.1.100"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$cluster1Name,
    
    [Parameter(Mandatory=$true)]
    [string]$cluster2Name,
    
    [Parameter(Mandatory=$true)]
    [string]$svmName,
    
    [Parameter(Mandatory=$true)]
    [string]$cifsName,
    
    [Parameter(Mandatory=$true)]
    [string]$cifsNameOld,
    
    [Parameter(Mandatory=$true)]
    [string]$SVMNewIP
)

# Import NetApp DataONTAP PowerShell module
try {
    Import-Module DataONTAP -ErrorAction Stop
    Write-Host "NetApp DataONTAP module imported successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import NetApp DataONTAP module. Please ensure it is installed."
    exit 1
}

# Function to handle errors
function Write-ErrorAndExit {
    param([string]$message)
    Write-Error $message
    exit 1
}

Write-Host "`n=== Starting SVM DR Activation Process ===" -ForegroundColor Cyan
Write-Host "Source Cluster: $cluster1Name" -ForegroundColor Yellow
Write-Host "Destination Cluster: $cluster2Name" -ForegroundColor Yellow
Write-Host "SVM Name: $svmName" -ForegroundColor Yellow

# =========================================
# PHASE 1: Operations on Source Cluster
# =========================================
Write-Host "`n--- Phase 1: Connecting to source cluster ($cluster1Name) ---" -ForegroundColor Cyan

try {
    $cluster1Connection = Connect-NcController -Name $cluster1Name -ErrorAction Stop
    Write-Host "Connected to source cluster successfully" -ForegroundColor Green
}
catch {
    Write-ErrorAndExit "Failed to connect to source cluster ${cluster1Name}: $_"
}

# Step 1: Set CIFS status to down
Write-Host "Setting CIFS server status to down on SVM: $svmName" -ForegroundColor Yellow
try {
    Set-NcCifsServer -VserverContext $svmName -AdminStatus down -Controller $cluster1Connection -ErrorAction Stop -Confirm:$false
    Write-Host "CIFS server status set to down" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to set CIFS status to down: $_"
}

# Step 2: Modify CIFS server name
Write-Host "Modifying CIFS server name from '$cifsNameOld' on SVM: $svmName" -ForegroundColor Yellow
try {
    Rename-NcCifsServer -VserverContext $svmName -CifsServer $cifsNameOld -Controller $cluster1Connection -ErrorAction Stop -Confirm:$false
    Write-Host "CIFS server renamed" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to modify CIFS server name: $_"
}

# Step 3: Stop the SVM
Write-Host "Stopping SVM: $svmName" -ForegroundColor Yellow
try {
    Stop-NcVserver -Name $svmName -Controller $cluster1Connection -ErrorAction Stop -Confirm:$false
    Write-Host "SVM stopped successfully" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to stop SVM: $_"
}

# =========================================
# PHASE 2: Operations on Destination Cluster
# =========================================
Write-Host "`n--- Phase 2: Connecting to destination cluster ($cluster2Name) ---" -ForegroundColor Cyan

try {
    $cluster2Connection = Connect-NcController -Name $cluster2Name -ErrorAction Stop
    Write-Host "Connected to destination cluster successfully" -ForegroundColor Green
}
catch {
    Write-ErrorAndExit "Failed to connect to destination cluster ${cluster2Name}: $_"
}

# Step 4: SnapMirror update
Write-Host "Updating SnapMirror relationship for destination: ${svmName}:" -ForegroundColor Yellow
try {
    Invoke-NcSnapmirrorUpdate -DestinationPath "${svmName}:" -Controller $cluster2Connection -ErrorAction Stop
    Write-Host "SnapMirror update initiated" -ForegroundColor Green
    
    # Wait for update to complete
    Write-Host "Waiting for SnapMirror update to complete..." -ForegroundColor Yellow
    do {
        Start-Sleep -Seconds 5
        $smStatus = Get-NcSnapmirror -DestinationPath "${svmName}:" -Controller $cluster2Connection
    } while ($smStatus.Status -eq "transferring")
    Write-Host "SnapMirror update completed" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to update SnapMirror: $_"
}

# Step 5: SnapMirror quiesce
Write-Host "Quiescing SnapMirror relationship for destination: ${svmName}:" -ForegroundColor Yellow
try {
    Invoke-NcSnapmirrorQuiesce -DestinationPath "${svmName}:" -Controller $cluster2Connection -ErrorAction Stop -Confirm:$false
    Write-Host "SnapMirror quiesced" -ForegroundColor Green
    
    # Wait for quiesce to complete
    Write-Host "Waiting for SnapMirror to quiesce..." -ForegroundColor Yellow
    do {
        Start-Sleep -Seconds 3
        $smStatus = Get-NcSnapmirror -DestinationPath "${svmName}:" -Controller $cluster2Connection
    } while ($smStatus.Status -ne "quiesced")
    Write-Host "SnapMirror quiesce completed" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to quiesce SnapMirror: $_"
}

# Step 6: SnapMirror break
Write-Host "Breaking SnapMirror relationship for destination: ${svmName}:" -ForegroundColor Yellow
try {
    Invoke-NcSnapmirrorBreak -DestinationPath "${svmName}:" -Controller $cluster2Connection -ErrorAction Stop -Confirm:$false
    Write-Host "SnapMirror relationship broken" -ForegroundColor Green
}
catch {
    Write-ErrorAndExit "Failed to break SnapMirror: $_"
}

# Step 7: Start the SVM on destination
Write-Host "Starting SVM on destination: $svmName" -ForegroundColor Yellow
try {
    Start-NcVserver -Name $svmName -Controller $cluster2Connection -ErrorAction Stop -Confirm:$false
    Write-Host "SVM started successfully" -ForegroundColor Green
}
catch {
    Write-ErrorAndExit "Failed to start SVM: $_"
}

# Step 8: Modify CIFS server name
Write-Host "Modifying CIFS server name to '$cifsName' on SVM: $svmName" -ForegroundColor Yellow
try {
    Rename-NcCifsServer -VserverContext $svmName -CifsServer $cifsName -Controller $cluster2Connection -ErrorAction Stop -Confirm:$false
    Write-Host "CIFS server name set to '$cifsName'" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to modify CIFS server name: $_"
}

# Step 9: Set CIFS status to up
Write-Host "Setting CIFS server status to up on SVM: $svmName" -ForegroundColor Yellow
try {
    Set-NcCifsServer -VserverContext $svmName -AdminStatus up -Controller $cluster2Connection -ErrorAction Stop -Confirm:$false
    Write-Host "CIFS server status set to up" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to set CIFS status to up: $_"
}

# =========================================
# PHASE 3: Update DNS Record
# =========================================
Write-Host "`n--- Phase 3: Updating DNS record ---" -ForegroundColor Cyan
Write-Host "Updating DNS record for hostname '$svmName' to IP '$SVMNewIP'" -ForegroundColor Yellow

try {
    # Get the DNS zone from the hostname
    $hostnameParts = $svmName.Split('.')
    if ($hostnameParts.Count -gt 1) {
        $hostname = $hostnameParts[0]
        $zoneName = $svmName.Substring($hostname.Length + 1)
    }
    else {
        $hostname = $svmName
        $zoneName = (Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled }).DNSDomain | Select-Object -First 1
    }
    
    Write-Host "Hostname: $hostname, Zone: $zoneName" -ForegroundColor Yellow
    
    # Try to get existing record
    $existingRecord = Get-DnsServerResourceRecord -Name $hostname -ZoneName $zoneName -RRType A -ErrorAction SilentlyContinue
    
    if ($existingRecord) {
        # Update existing record
        $newRecord = $existingRecord.Clone()
        $newRecord.RecordData.IPv4Address = [System.Net.IPAddress]::Parse($SVMNewIP)
        Set-DnsServerResourceRecord -NewInputObject $newRecord -OldInputObject $existingRecord -ZoneName $zoneName -ErrorAction Stop
        Write-Host "DNS A record updated successfully" -ForegroundColor Green
    }
    else {
        # Create new record
        Add-DnsServerResourceRecordA -Name $hostname -ZoneName $zoneName -IPv4Address $SVMNewIP -ErrorAction Stop
        Write-Host "DNS A record created successfully" -ForegroundColor Green
    }
}
catch {
    Write-Warning "Failed to update DNS record: $_"
    Write-Host "You may need to manually update the DNS record for $svmName to $SVMNewIP" -ForegroundColor Yellow
}

# =========================================
# Completion
# =========================================
Write-Host "`n=== SVM DR Activation Process Completed ===" -ForegroundColor Green
Write-Host "SVM '$svmName' has been activated on destination cluster '$cluster2Name'" -ForegroundColor Green
Write-Host "CIFS server '$cifsName' is now active with status up" -ForegroundColor Green
Write-Host "DNS record updated to IP: $SVMNewIP" -ForegroundColor Green
