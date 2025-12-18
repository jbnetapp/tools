<#
.SYNOPSIS
    Force update of LastLogonTimestamp for AD computer objects
.DESCRIPTION
    This script forces an update of the LastLogonTimestamp attribute for specified AD computer objects
    by modifying a non-critical attribute to trigger replication
.PARAMETER ComputerName
    Name of the computer object to update
.PARAMETER InputFile
    Path to text file containing computer names (one per line)
.PARAMETER All
    Update all computer objects in the domain (use with caution)
.PARAMETER WhatIf
    Show what would be done without making changes
.EXAMPLE
    .\Update-LastLogonTimestamp.ps1 -ComputerName "PC001"
.EXAMPLE
    .\Update-LastLogonTimestamp.ps1 -InputFile "computers.txt"
.EXAMPLE
    .\Update-LastLogonTimestamp.ps1 -ComputerName "PC001" -WhatIf
#>

param(
    [Parameter(Mandatory=$false)]
    [string[]]$ComputerName,
    
    [Parameter(Mandatory=$false)]
    [string]$InputFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$All,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Definition -Full
    exit
}

# Check if ActiveDirectory module is available
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "Active Directory module loaded successfully." -ForegroundColor Green
} catch {
    Write-Host "Error: Active Directory module not available." -ForegroundColor Red
    Write-Host "Please install RSAT tools or run this script on a domain controller." -ForegroundColor Yellow
    exit 1
}

function Update-ComputerLastLogon {
    param(
        [string]$Computer,
        [switch]$WhatIfMode
    )
    
    try {
        # Get the computer object
        $computerObj = Get-ADComputer -Identity $Computer -Properties LastLogonTimestamp, Description -ErrorAction Stop
        
        # Display current LastLogonTimestamp
        $currentLastLogon = if ($computerObj.LastLogonTimestamp) {
            [DateTime]::FromFileTime($computerObj.LastLogonTimestamp).ToString("yyyy-MM-dd HH:mm:ss")
        } else {
            "Never"
        }
        
        Write-Host "Computer: $($computerObj.Name)" -ForegroundColor Cyan
        Write-Host "  Current LastLogonTimestamp: $currentLastLogon" -ForegroundColor Gray
        
        if ($WhatIfMode) {
            Write-Host "  WHATIF: Would update LastLogonTimestamp by modifying description" -ForegroundColor Yellow
        } else {
            # Method 1: Modify description to trigger timestamp update
            $currentDescription = $computerObj.Description
            $tempDescription = if ([string]::IsNullOrEmpty($currentDescription)) {
                "LastLogon-Update-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            } else {
                "$currentDescription [Updated-$(Get-Date -Format 'yyyyMMdd-HHmmss')]"
            }
            
            # Update with temporary description
            Set-ADComputer -Identity $Computer -Description $tempDescription
            Write-Host "  Step 1: Updated description to trigger replication" -ForegroundColor Yellow
            
            # Wait a moment for AD to process
            Start-Sleep -Seconds 2
            
            # Restore original description
            if ([string]::IsNullOrEmpty($currentDescription)) {
                Set-ADComputer -Identity $Computer -Clear Description
            } else {
                Set-ADComputer -Identity $Computer -Description $currentDescription
            }
            Write-Host "  Step 2: Restored original description" -ForegroundColor Yellow
            
            # Verify the update
            $updatedComputer = Get-ADComputer -Identity $Computer -Properties LastLogonTimestamp
            $newLastLogon = if ($updatedComputer.LastLogonTimestamp) {
                [DateTime]::FromFileTime($updatedComputer.LastLogonTimestamp).ToString("yyyy-MM-dd HH:mm:ss")
            } else {
                "Never"
            }
            
            Write-Host "  Updated LastLogonTimestamp: $newLastLogon" -ForegroundColor Green
        }
        
        Write-Host ""
        return $true
        
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Host "  ERROR: Computer '$Computer' not found in Active Directory" -ForegroundColor Red
        Write-Host ""
        return $false
    } catch {
        Write-Host "  ERROR: Failed to update computer '$Computer': $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        return $false
    }
}

function Get-ComputerList {
    $computers = @()
    
    if ($All) {
        Write-Host "Getting all computer objects from Active Directory..." -ForegroundColor Yellow
        try {
            $computers = (Get-ADComputer -Filter * | Select-Object -ExpandProperty Name)
            Write-Host "Found $($computers.Count) computer objects" -ForegroundColor Green
        } catch {
            Write-Host "Error getting computer list: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
    elseif ($InputFile) {
        if (Test-Path $InputFile) {
            $computers = Get-Content $InputFile | Where-Object { $_.Trim() -ne "" }
            Write-Host "Loaded $($computers.Count) computers from file: $InputFile" -ForegroundColor Green
        } else {
            Write-Host "Error: File '$InputFile' not found" -ForegroundColor Red
            exit 1
        }
    }
    elseif ($ComputerName) {
        $computers = $ComputerName
    }
    else {
        Write-Host "Error: Must specify -ComputerName, -InputFile, or -All" -ForegroundColor Red
        Write-Host "Use -Help for usage information" -ForegroundColor Yellow
        exit 1
    }
    
    return $computers
}

# Main execution
Write-Host "=== AD Computer LastLogonTimestamp Updater ===" -ForegroundColor Green
Write-Host ""

# Confirm for bulk operations
if ($All -and -not $WhatIf) {
    $confirm = Read-Host "You are about to update ALL computer objects in the domain. Continue? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit
    }
}

# Get list of computers to process
$computerList = Get-ComputerList

if ($computerList.Count -eq 0) {
    Write-Host "No computers to process." -ForegroundColor Yellow
    exit
}

Write-Host "Processing $($computerList.Count) computer(s)..." -ForegroundColor Cyan
Write-Host ""

# Process each computer
$successCount = 0
$failCount = 0

foreach ($comp in $computerList) {
    if (Update-ComputerLastLogon -Computer $comp.Trim() -WhatIfMode:$WhatIf) {
        $successCount++
    } else {
        $failCount++
    }
}

# Summary
Write-Host "=== Summary ===" -ForegroundColor Green
Write-Host "Total processed: $($computerList.Count)" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red

if ($WhatIf) {
    Write-Host ""
    Write-Host "This was a preview run. Use without -WhatIf to make actual changes." -ForegroundColor Yellow
}