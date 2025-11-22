<#
.SYNOPSIS
    Advanced Disk Space Monitoring Tool
    
.DESCRIPTION
    This script provides comprehensive disk space monitoring for both local and remote Windows systems.
    It combines functionality to check disk space locally or on remote computers via PowerShell remoting.
    
.PARAMETER ComputerName
    The name of the computer to check. Use 'localhost' or leave empty for local machine.
    Can accept multiple computer names separated by commas.
    
.PARAMETER Credential
    PSCredential object for authentication to remote computers (optional)
    
.PARAMETER ExportPath
    Path to export the results to a CSV file (optional)
    
.PARAMETER ThresholdWarning
    Percentage threshold for warning status (default: 20%)
    
.PARAMETER ThresholdCritical
    Percentage threshold for critical/low status (default: 10%)
    
.EXAMPLE
    .\DiskSpaceMonitor.ps1
    Checks disk space on the local machine
    
.EXAMPLE
    .\DiskSpaceMonitor.ps1 -ComputerName "SERVER01,SERVER02"
    Checks disk space on multiple remote computers
    
.EXAMPLE
    .\DiskSpaceMonitor.ps1 -ComputerName "SERVER01" -ExportPath "C:\Reports\diskspace.csv"
    Checks remote computer and exports results to CSV
    
.NOTES
    Author: Combined Script
    Version: 2.0
    Requires: PowerShell 5.1 or higher
    For remote computers: Requires WinRM to be configured and appropriate permissions
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string[]]$ComputerName = @($env:COMPUTERNAME),
    
    [Parameter()]
    [PSCredential]$Credential,
    
    [Parameter()]
    [string]$ExportPath,
    
    [Parameter()]
    [ValidateRange(1,99)]
    [int]$ThresholdWarning = 20,
    
    [Parameter()]
    [ValidateRange(1,99)]
    [int]$ThresholdCritical = 10,
    
    [Parameter()]
    [switch]$ShowOnlyProblems,
    
    [Parameter()]
    [switch]$IncludeSystemInfo
)

#region Helper Functions

function Write-ColoredOutput {
    <#
    .SYNOPSIS
        Helper function to write colored output with timestamps
    #>
    param(
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewLine
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($NoNewLine) {
        Write-Host "[$timestamp] $Message" -ForegroundColor $Color -NoNewline
    } else {
        Write-Host "[$timestamp] $Message" -ForegroundColor $Color
    }
}

function Get-DriveTypeDescription {
    <#
    .SYNOPSIS
        Converts numeric drive type to readable description
    #>
    param([int]$DriveType)
    
    switch($DriveType) {
        0 { return "Unknown" }
        1 { return "No Root Directory" }
        2 { return "Removable" }
        3 { return "Local Disk" }
        4 { return "Network Drive" }
        5 { return "CD/DVD" }
        6 { return "RAM Disk" }
        default { return "Unknown" }
    }
}

function Get-StatusFromPercentage {
    <#
    .SYNOPSIS
        Determines status based on free space percentage
    #>
    param(
        [double]$FreePercent,
        [int]$Warning = $ThresholdWarning,
        [int]$Critical = $ThresholdCritical
    )
    
    if ($FreePercent -lt $Critical) {
        return "CRITICAL"
    } elseif ($FreePercent -lt $Warning) {
        return "WARNING"
    } else {
        return "OK"
    }
}

function Format-ByteSize {
    <#
    .SYNOPSIS
        Formats byte values into readable sizes
    #>
    param([double]$Bytes)
    
    $sizes = 'Bytes', 'KB', 'MB', 'GB', 'TB', 'PB'
    $i = 0
    while ($Bytes -ge 1024 -and $i -lt $sizes.Count - 1) {
        $Bytes /= 1024
        $i++
    }
    return "{0:N2} {1}" -f $Bytes, $sizes[$i]
}

#endregion Helper Functions

#region Main Functions

function Get-LocalDiskSpace {
    <#
    .SYNOPSIS
        Gets disk space information from the local computer using CIM
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-ColoredOutput "Gathering local disk information..." -Color Cyan
        
        # Get disk information using CIM (more efficient than WMI)
        $drives = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop | 
            Where-Object { $_.Size -gt 0 }
        
        # Get additional system information if requested
        $systemInfo = $null
        if ($IncludeSystemInfo) {
            $os = Get-CimInstance Win32_OperatingSystem
            $computer = Get-CimInstance Win32_ComputerSystem
            
            $systemInfo = [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                OperatingSystem = $os.Caption
                Architecture = $os.OSArchitecture
                LastBootTime = $os.LastBootUpTime
                TotalPhysicalMemory = Format-ByteSize $computer.TotalPhysicalMemory
            }
        }
        
        # Process each drive
        $driveInfo = $drives | ForEach-Object {
            $freePercent = if ($_.Size -gt 0) { 
                ($_.FreeSpace / $_.Size) * 100 
            } else { 
                0 
            }
            
            $status = Get-StatusFromPercentage -FreePercent $freePercent
            
            # Create custom object with all drive information
            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                Drive = $_.DeviceID
                Label = $_.VolumeName
                FileSystem = $_.FileSystem
                Type = Get-DriveTypeDescription -DriveType $_.DriveType
                'Total(GB)' = [math]::Round($_.Size / 1GB, 2)
                'Free(GB)' = [math]::Round($_.FreeSpace / 1GB, 2)
                'Used(GB)' = [math]::Round(($_.Size - $_.FreeSpace) / 1GB, 2)
                'Free(%)' = [math]::Round($freePercent, 2)
                'Used(%)' = [math]::Round(100 - $freePercent, 2)
                Status = $status
                StatusColor = switch($status) {
                    "CRITICAL" { "Red" }
                    "WARNING" { "Yellow" }
                    "OK" { "Green" }
                }
            }
        }
        
        return @{
            Success = $true
            DriveInfo = $driveInfo
            SystemInfo = $systemInfo
            TotalDrives = $drives.Count
            TotalSize = ($drives | Measure-Object -Property Size -Sum).Sum
            TotalFree = ($drives | Measure-Object -Property FreeSpace -Sum).Sum
        }
    }
    catch {
        Write-ColoredOutput "Error getting local disk information: $_" -Color Red
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-RemoteDiskSpace {
    <#
    .SYNOPSIS
        Gets disk space information from remote computers using PowerShell remoting
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,
        
        [PSCredential]$Credential
    )
    
    try {
        Write-ColoredOutput "Connecting to remote computer: $ComputerName..." -Color Cyan
        
        # Test connection first
        if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
            throw "Cannot reach computer: $ComputerName"
        }
        
        # Prepare remote command parameters
        $invokeParams = @{
            ComputerName = $ComputerName
            ErrorAction = 'Stop'
        }
        
        if ($Credential) {
            $invokeParams['Credential'] = $Credential
        }
        
        # Script block to run on remote computer
        $scriptBlock = {
            param($IncludeSysInfo, $ThresholdWarn, $ThresholdCrit)
            
            $drives = Get-WmiObject -Class Win32_LogicalDisk | 
                Where-Object { $_.Size -gt 0 }
            
            $systemInfo = $null
            if ($IncludeSysInfo) {
                $os = Get-WmiObject Win32_OperatingSystem
                $computer = Get-WmiObject Win32_ComputerSystem
                
                $systemInfo = @{
                    ComputerName = $env:COMPUTERNAME
                    OperatingSystem = $os.Caption
                    Architecture = $os.OSArchitecture
                    LastBootTime = $os.ConvertToDateTime($os.LastBootUpTime)
                    TotalPhysicalMemory = $computer.TotalPhysicalMemory
                }
            }
            
            $driveReport = $drives | ForEach-Object {
                $freePercent = if ($_.Size -gt 0) { 
                    ($_.FreeSpace / $_.Size) * 100 
                } else { 
                    0 
                }
                
                $status = if ($freePercent -lt $ThresholdCrit) { 
                    "CRITICAL" 
                } elseif ($freePercent -lt $ThresholdWarn) { 
                    "WARNING" 
                } else { 
                    "OK" 
                }
                
                @{
                    ComputerName = $env:COMPUTERNAME
                    Drive = $_.DeviceID
                    Label = $_.VolumeName
                    FileSystem = $_.FileSystem
                    Type = switch($_.DriveType){
                        0 {"Unknown"}
                        1 {"No Root Directory"}
                        2 {"Removable"}
                        3 {"Local Disk"}
                        4 {"Network Drive"}
                        5 {"CD/DVD"}
                        6 {"RAM Disk"}
                        default {"Unknown"}
                    }
                    'Total(GB)' = [math]::Round($_.Size/1GB, 2)
                    'Free(GB)' = [math]::Round($_.FreeSpace/1GB, 2)
                    'Used(GB)' = [math]::Round(($_.Size - $_.FreeSpace)/1GB, 2)
                    'Free(%)' = [math]::Round($freePercent, 2)
                    'Used(%)' = [math]::Round(100 - $freePercent, 2)
                    Status = $status
                }
            }
            
            return @{
                Drives = $driveReport
                SystemInfo = $systemInfo
                TotalSize = ($drives | Measure-Object -Property Size -Sum).Sum
                TotalFree = ($drives | Measure-Object -Property FreeSpace -Sum).Sum
                TotalDrives = $drives.Count
            }
        }
        
        # Execute remote command
        $invokeParams['ScriptBlock'] = $scriptBlock
        $invokeParams['ArgumentList'] = @($IncludeSystemInfo, $ThresholdWarning, $ThresholdCritical)
        
        $remoteData = Invoke-Command @invokeParams
        
        # Convert hashtables back to PSCustomObjects
        $driveInfo = $remoteData.Drives | ForEach-Object {
            $drive = $_
            [PSCustomObject]@{
                ComputerName = $drive.ComputerName
                Drive = $drive.Drive
                Label = $drive.Label
                FileSystem = $drive.FileSystem
                Type = $drive.Type
                'Total(GB)' = $drive.'Total(GB)'
                'Free(GB)' = $drive.'Free(GB)'
                'Used(GB)' = $drive.'Used(GB)'
                'Free(%)' = $drive.'Free(%)'
                'Used(%)' = $drive.'Used(%)'
                Status = $drive.Status
                StatusColor = switch($drive.Status) {
                    "CRITICAL" { "Red" }
                    "WARNING" { "Yellow" }
                    "OK" { "Green" }
                }
            }
        }
        
        $sysInfo = $null
        if ($remoteData.SystemInfo) {
            $si = $remoteData.SystemInfo
            $sysInfo = [PSCustomObject]@{
                ComputerName = $si.ComputerName
                OperatingSystem = $si.OperatingSystem
                Architecture = $si.Architecture
                LastBootTime = $si.LastBootTime
                TotalPhysicalMemory = Format-ByteSize $si.TotalPhysicalMemory
            }
        }
        
        return @{
            Success = $true
            DriveInfo = $driveInfo
            SystemInfo = $sysInfo
            TotalDrives = $remoteData.TotalDrives
            TotalSize = $remoteData.TotalSize
            TotalFree = $remoteData.TotalFree
        }
    }
    catch {
        Write-ColoredOutput "Error getting remote disk information from ${ComputerName}: $_" -Color Red
        return @{
            Success = $false
            ComputerName = $ComputerName
            Error = $_.Exception.Message
        }
    }
}

function Show-DiskSpaceReport {
    <#
    .SYNOPSIS
        Displays formatted disk space report
    #>
    param(
        [Parameter(Mandatory)]
        $DiskData,
        
        [string]$ComputerName
    )
    
    if (-not $DiskData.Success) {
        Write-ColoredOutput "Failed to retrieve data from $ComputerName" -Color Red
        Write-ColoredOutput "Error: $($DiskData.Error)" -Color Red
        return
    }
    
    # Header
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "DISK SPACE REPORT - $ComputerName" -ForegroundColor Green
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host ""
    
    # System Information (if available)
    if ($DiskData.SystemInfo) {
        Write-Host "SYSTEM INFORMATION" -ForegroundColor Yellow
        Write-Host ("-" * 40) -ForegroundColor Yellow
        $DiskData.SystemInfo | Format-List
        Write-Host ""
    }
    
    # Drive Information
    Write-Host "DRIVE DETAILS" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor Yellow
    
    $drives = $DiskData.DriveInfo
    
    # Filter if ShowOnlyProblems is specified
    if ($ShowOnlyProblems) {
        $drives = $drives | Where-Object { $_.Status -ne "OK" }
        if (-not $drives) {
            Write-ColoredOutput "All drives are healthy!" -Color Green
            return
        }
    }
    
    # Display drives grouped by status
    $criticalDrives = $drives | Where-Object { $_.Status -eq "CRITICAL" }
    $warningDrives = $drives | Where-Object { $_.Status -eq "WARNING" }
    $okDrives = $drives | Where-Object { $_.Status -eq "OK" }
    
    if ($criticalDrives) {
        Write-Host "`n❌ CRITICAL DRIVES:" -ForegroundColor Red
        $criticalDrives | Format-Table -AutoSize
    }
    
    if ($warningDrives) {
        Write-Host "`n⚠️  WARNING DRIVES:" -ForegroundColor Yellow
        $warningDrives | Format-Table -AutoSize
    }
    
    if ($okDrives -and -not $ShowOnlyProblems) {
        Write-Host "`n✅ HEALTHY DRIVES:" -ForegroundColor Green
        $okDrives | Format-Table -AutoSize
    }
    
    # Summary Statistics
    Write-Host ""
    Write-Host "SUMMARY STATISTICS" -ForegroundColor Cyan
    Write-Host ("-" * 40) -ForegroundColor Cyan
    
    $totalSizeGB = [math]::Round($DiskData.TotalSize / 1GB, 2)
    $totalFreeGB = [math]::Round($DiskData.TotalFree / 1GB, 2)
    $totalUsedGB = [math]::Round(($DiskData.TotalSize - $DiskData.TotalFree) / 1GB, 2)
    $overallFreePercent = if ($DiskData.TotalSize -gt 0) {
        [math]::Round(($DiskData.TotalFree / $DiskData.TotalSize) * 100, 2)
    } else { 0 }
    
    Write-Host "Total Drives: $($DiskData.TotalDrives)" -ForegroundColor White
    Write-Host "Total Capacity: $totalSizeGB GB" -ForegroundColor White
    Write-Host "Total Used: $totalUsedGB GB" -ForegroundColor White
    Write-Host "Total Free: $totalFreeGB GB" -ForegroundColor White
    Write-Host "Overall Free: $overallFreePercent%" -ForegroundColor $(
        if ($overallFreePercent -lt 10) { "Red" }
        elseif ($overallFreePercent -lt 20) { "Yellow" }
        else { "Green" }
    )
    
    # Recommendations
    if ($criticalDrives) {
        Write-Host ""
        Write-Host "⚠️  RECOMMENDATIONS:" -ForegroundColor Red
        Write-Host "- Immediate action required for drives with CRITICAL status" -ForegroundColor Red
        Write-Host "- Consider cleaning up temporary files or moving data" -ForegroundColor Yellow
        Write-Host "- Run Disk Cleanup utility (cleanmgr.exe)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Cyan
}

function Export-DiskSpaceReport {
    <#
    .SYNOPSIS
        Exports disk space report to CSV file
    #>
    param(
        [Parameter(Mandatory)]
        $DiskData,
        
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    try {
        $exportData = @()
        
        foreach ($computer in $DiskData) {
            if ($computer.Success) {
                $exportData += $computer.DriveInfo
            }
        }
        
        if ($exportData.Count -gt 0) {
            $exportData | Export-Csv -Path $Path -NoTypeInformation -Force
            Write-ColoredOutput "Report exported to: $Path" -Color Green
            
            # Also create a summary file
            $summaryPath = $Path -replace '\.csv$', '_summary.txt'
            $summaryContent = @()
            
            foreach ($computer in $DiskData) {
                if ($computer.Success) {
                    $summaryContent += "Computer: $($computer.DriveInfo[0].ComputerName)"
                    $summaryContent += "Total Drives: $($computer.TotalDrives)"
                    $summaryContent += "Total Size: $([math]::Round($computer.TotalSize / 1GB, 2)) GB"
                    $summaryContent += "Total Free: $([math]::Round($computer.TotalFree / 1GB, 2)) GB"
                    $summaryContent += "Critical Drives: $(($computer.DriveInfo | Where-Object {$_.Status -eq 'CRITICAL'}).Count)"
                    $summaryContent += "Warning Drives: $(($computer.DriveInfo | Where-Object {$_.Status -eq 'WARNING'}).Count)"
                    $summaryContent += "-" * 40
                }
            }
            
            $summaryContent | Out-File -FilePath $summaryPath -Force
            Write-ColoredOutput "Summary exported to: $summaryPath" -Color Green
        }
    }
    catch {
        Write-ColoredOutput "Error exporting report: $_" -Color Red
    }
}

#endregion Main Functions

#region Main Script Execution

function Main {
    # Display script header
    Clear-Host
    Write-Host @"
╔════════════════════════════════════════════════════════════════════╗
║              ADVANCED DISK SPACE MONITORING TOOL v2.0              ║
╚════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    
    Write-ColoredOutput "Starting disk space analysis..." -Color Green
    Write-Host ""
    
    # Collection to store all results
    $allResults = @()
    
    # Process each computer
    foreach ($computer in $ComputerName) {
        # Determine if local or remote
        $isLocal = $computer -eq $env:COMPUTERNAME -or 
                   $computer -eq "localhost" -or 
                   $computer -eq "." -or
                   $computer -eq "127.0.0.1"
        
        if ($isLocal) {
            Write-ColoredOutput "Checking local computer..." -Color Cyan
            $result = Get-LocalDiskSpace
        } else {
            Write-ColoredOutput "Checking remote computer: $computer" -Color Cyan
            $result = Get-RemoteDiskSpace -ComputerName $computer -Credential $Credential
        }
        
        # Display the report
        Show-DiskSpaceReport -DiskData $result -ComputerName $computer
        
        # Add to collection
        $allResults += $result
    }
    
    # Export if requested
    if ($ExportPath) {
        Export-DiskSpaceReport -DiskData $allResults -Path $ExportPath
    }
    
    # Final summary for multiple computers
    if ($ComputerName.Count -gt 1) {
        Write-Host ""
        Write-Host "OVERALL SUMMARY - ALL COMPUTERS" -ForegroundColor Magenta
        Write-Host ("=" * 80) -ForegroundColor Magenta
        
        $totalComputers = $ComputerName.Count
        $successfulChecks = ($allResults | Where-Object { $_.Success }).Count
        $failedChecks = $totalComputers - $successfulChecks
        
        Write-Host "Total Computers Checked: $totalComputers" -ForegroundColor White
        Write-Host "Successful: $successfulChecks" -ForegroundColor Green
        Write-Host "Failed: $failedChecks" -ForegroundColor $(if ($failedChecks -gt 0) {"Red"} else {"Green"})
        
        # Aggregate statistics
        $allDrives = $allResults | Where-Object { $_.Success } | ForEach-Object { $_.DriveInfo }
        $criticalCount = ($allDrives | Where-Object { $_.Status -eq "CRITICAL" }).Count
        $warningCount = ($allDrives | Where-Object { $_.Status -eq "WARNING" }).Count
        
        if ($criticalCount -gt 0) {
            Write-Host "`n❌ Total Critical Drives: $criticalCount" -ForegroundColor Red
        }
        if ($warningCount -gt 0) {
            Write-Host "⚠️  Total Warning Drives: $warningCount" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-ColoredOutput "Disk space analysis completed!" -Color Green
    Write-Host ""
}

# Execute main function
Main

# Pause at the end if running interactively
if ($Host.Name -eq "ConsoleHost") {
    Write-Host ""
    Read-Host "Press Enter to exit"
}

#endregion Main Script Execution