


<img width="1020" height="582" alt="image" src="https://github.com/user-attachments/assets/0321b7e9-f975-4c95-b957-14665f15a0da" />

# DiskSpaceMonitor PowerShell Script

## Overview
DiskSpaceMonitor.ps1 is a comprehensive PowerShell script that combines local and remote disk space monitoring capabilities into a single, powerful tool. It provides detailed disk space analysis with customizable thresholds, export capabilities, and rich formatting.

## Features

### Core Capabilities
- **Local Disk Monitoring**: Check disk space on the local machine using CIM instances
- **Remote Disk Monitoring**: Check disk space on remote computers via PowerShell remoting (WinRM)
- **Multi-Computer Support**: Check multiple computers in a single run
- **Smart Status Detection**: Automatic status assignment based on free space thresholds
- **Export Functionality**: Export results to CSV with automatic summary generation
- **System Information**: Optional collection of system details (OS, architecture, memory, boot time)
- **Colored Output**: Visual indicators for different status levels (OK/WARNING/CRITICAL)
- **Problem Filtering**: Option to show only drives with issues

### Advanced Features
- Custom warning and critical thresholds
- Credential support for remote authentication
- Detailed drive information (label, file system, type)
- Aggregate statistics across all drives
- Automatic recommendations for low disk space
- Progress timestamps for all operations
- Error handling with detailed error messages

## Requirements

### System Requirements
- **PowerShell Version**: 5.1 or higher
- **Operating System**: Windows 7/Server 2008 R2 or higher
- **Permissions**: 
  - Local checks: Standard user rights
  - Remote checks: Administrator rights on target computer

### Remote Computer Requirements
- WinRM service must be enabled and configured
- Firewall must allow WinRM traffic (default port 5985 for HTTP, 5986 for HTTPS)
- User must have appropriate permissions on remote computer

## Installation

1. Download the `DiskSpaceMonitor.ps1` script
2. Place it in a convenient location (e.g., `C:\Scripts\`)
3. Optionally, add the script location to your PATH environment variable

## Usage Examples

### Basic Usage

#### Check Local Computer
```powershell
.\DiskSpaceMonitor.ps1
```

#### Check Remote Computer
```powershell
.\DiskSpaceMonitor.ps1 -ComputerName "SERVER01"
```

#### Check Multiple Computers
```powershell
.\DiskSpaceMonitor.ps1 -ComputerName "SERVER01","SERVER02","SERVER03"
```

### Advanced Usage

#### With Custom Thresholds
```powershell
.\DiskSpaceMonitor.ps1 -ComputerName "SERVER01" -ThresholdWarning 30 -ThresholdCritical 15
```

#### With Credentials
```powershell
$cred = Get-Credential
.\DiskSpaceMonitor.ps1 -ComputerName "SERVER01" -Credential $cred
```

#### Export to CSV
```powershell
.\DiskSpaceMonitor.ps1 -ComputerName "SERVER01","SERVER02" -ExportPath "C:\Reports\diskspace.csv"
```

#### Show Only Problems
```powershell
.\DiskSpaceMonitor.ps1 -ComputerName "SERVER01" -ShowOnlyProblems
```

#### Include System Information
```powershell
.\DiskSpaceMonitor.ps1 -ComputerName "SERVER01" -IncludeSystemInfo
```

#### Complete Example with All Options
```powershell
$computers = @("SERVER01", "SERVER02", "WEB01", "DB01")
$cred = Get-Credential DOMAIN\AdminUser

.\DiskSpaceMonitor.ps1 `
    -ComputerName $computers `
    -Credential $cred `
    -ThresholdWarning 25 `
    -ThresholdCritical 10 `
    -ExportPath "C:\Reports\DiskSpace_$(Get-Date -Format 'yyyyMMdd').csv" `
    -IncludeSystemInfo `
    -ShowOnlyProblems
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-ComputerName` | String[] | localhost | Computer(s) to check. Accepts array of names |
| `-Credential` | PSCredential | Current user | Credentials for remote authentication |
| `-ExportPath` | String | None | Path to export CSV file |
| `-ThresholdWarning` | Int | 20 | Free space % threshold for WARNING status |
| `-ThresholdCritical` | Int | 10 | Free space % threshold for CRITICAL status |
| `-ShowOnlyProblems` | Switch | False | Only display drives with WARNING or CRITICAL status |
| `-IncludeSystemInfo` | Switch | False | Include system information in the report |

## Output Information

### Drive Information Displayed
- **ComputerName**: Name of the computer
- **Drive**: Drive letter (e.g., C:)
- **Label**: Volume label
- **FileSystem**: File system type (NTFS, FAT32, etc.)
- **Type**: Drive type (Local Disk, Network Drive, Removable, etc.)
- **Total(GB)**: Total drive capacity in gigabytes
- **Free(GB)**: Free space in gigabytes
- **Used(GB)**: Used space in gigabytes
- **Free(%)**: Percentage of free space
- **Used(%)**: Percentage of used space
- **Status**: OK, WARNING, or CRITICAL

### Status Indicators
- ✅ **OK** (Green): Free space above warning threshold
- ⚠️ **WARNING** (Yellow): Free space below warning threshold but above critical
- ❌ **CRITICAL** (Red): Free space below critical threshold

## Troubleshooting

### Common Issues and Solutions

#### Issue: Cannot connect to remote computer
**Solution**: 
- Verify WinRM is enabled: `winrm quickconfig`
- Check if the computer is reachable: `Test-Connection COMPUTERNAME`
- Verify firewall settings allow WinRM traffic
- Ensure you have appropriate permissions

#### Issue: Access Denied on remote computer
**Solution**:
- Use `-Credential` parameter with appropriate admin credentials
- Verify the account has local administrator rights on target computer
- Check if UAC is interfering (may need to use domain admin account)

#### Issue: WinRM is not configured
**Solution**:
Run the following on the target computer as administrator:
```powershell
Enable-PSRemoting -Force
```

#### Issue: Script execution is disabled
**Solution**:
Set execution policy to allow scripts:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Enabling WinRM for Remote Management

On target computers, run as Administrator:
```powershell
# Quick configuration
winrm quickconfig

# Or more detailed setup
Enable-PSRemoting -Force
Set-Item wsman:\localhost\client\trustedhosts * -Force
Restart-Service WinRM
```

### Testing Remote Connectivity
```powershell
# Test WinRM connectivity
Test-WSMan -ComputerName "SERVER01"

# Test PowerShell remoting
Enter-PSSession -ComputerName "SERVER01"
```

## Security Considerations

1. **Credentials**: Never hardcode credentials in scripts. Always use `Get-Credential` or secure credential storage
2. **Execution Policy**: Use appropriate execution policy for your environment
3. **WinRM Security**: Consider using HTTPS for WinRM in production environments
4. **Audit Logging**: Remote connections are logged in Windows Security Event Log
5. **Least Privilege**: Use accounts with minimum required permissions

## Performance Tips

1. **Parallel Processing**: For many computers, consider using PowerShell jobs or workflows
2. **Filtering**: Use `-ShowOnlyProblems` to reduce output when monitoring many drives
3. **Scheduling**: Use Task Scheduler to run the script regularly and export results
4. **Network Optimization**: For slow networks, consider increasing WinRM timeout values

## Integration Examples

### Scheduled Task
Create a scheduled task to run daily and email results:
```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\Scripts\DiskSpaceMonitor.ps1 -ComputerName SERVER01,SERVER02 -ExportPath C:\Reports\daily_disk.csv"
$trigger = New-ScheduledTaskTrigger -Daily -At 6:00AM
Register-ScheduledTask -TaskName "DiskSpaceMonitor" -Action $action -Trigger $trigger
```

### Email Integration
Add email functionality to the script:
```powershell
# After running the script and getting results
Send-MailMessage `
    -To "admin@company.com" `
    -From "monitor@company.com" `
    -Subject "Disk Space Report - $(Get-Date -Format 'yyyy-MM-dd')" `
    -Body "See attached disk space report" `
    -Attachments "C:\Reports\diskspace.csv" `
    -SmtpServer "mail.company.com"
```

## Version History

- **v2.0**: Combined local and remote functionality, added multi-computer support, export capabilities
- **v1.1**: Added remote computer support
- **v1.0**: Initial release with local disk checking

## Author and Support

This script combines functionality from two separate disk monitoring scripts to provide a comprehensive solution for Windows disk space management.

## License

This script is provided as-is for educational and administrative purposes. Feel free to modify and distribute according to your needs.

## Additional Resources

- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [WinRM Configuration Guide](https://docs.microsoft.com/windows/win32/winrm/portal)
- [CIM vs WMI Comparison](https://docs.microsoft.com/powershell/scripting/learn/ps101/07-working-with-wmi)
