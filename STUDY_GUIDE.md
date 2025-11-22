# Complete Study Guide: DiskSpaceMonitor.ps1

## Table of Contents
1. [Script Structure Overview](#script-structure-overview)
2. [PowerShell Concepts Used](#powershell-concepts-used)
3. [Detailed Code Walkthrough](#detailed-code-walkthrough)
4. [Functions Explained](#functions-explained)
5. [Advanced PowerShell Techniques](#advanced-powershell-techniques)
6. [WMI/CIM Classes Explained](#wmicim-classes-explained)
7. [PowerShell Remoting Deep Dive](#powershell-remoting-deep-dive)
8. [Best Practices Demonstrated](#best-practices-demonstrated)

---

## Script Structure Overview

The script is organized into several logical sections:

```
1. Comment-Based Help (.SYNOPSIS, .DESCRIPTION, etc.)
2. Parameter Declaration Block
3. Helper Functions Region
4. Main Functions Region
5. Main Execution Block
```

This structure follows PowerShell best practices for maintainability and readability.

---

## PowerShell Concepts Used

### 1. Comment-Based Help
```powershell
<#
.SYNOPSIS
    Brief description
.DESCRIPTION
    Detailed description
.PARAMETER
    Parameter explanations
.EXAMPLE
    Usage examples
#>
```
**Purpose**: Enables `Get-Help` functionality for the script, providing built-in documentation.

### 2. CmdletBinding Attribute
```powershell
[CmdletBinding()]
```
**Purpose**: Transforms the function into an advanced function with features like:
- Common parameters (-Verbose, -Debug, -ErrorAction)
- Parameter validation
- Pipeline support
- Confirmation prompts

### 3. Parameter Attributes
```powershell
[Parameter(Position=0)]
[ValidateRange(1,99)]
```
**Purpose**: Provides parameter validation and behavior control:
- `Position`: Allows positional parameter binding
- `ValidateRange`: Ensures numeric values fall within acceptable range
- `Mandatory`: Requires the parameter be provided

### 4. Script Blocks
```powershell
$scriptBlock = { 
    # Code to execute remotely
}
```
**Purpose**: Encapsulates code for remote execution or delayed execution

---

## Detailed Code Walkthrough

### Parameter Block Analysis

```powershell
param(
    [Parameter(Position=0)]
    [string[]]$ComputerName = @($env:COMPUTERNAME),
```
**Explanation**: 
- `[string[]]` - Array of strings, allowing multiple computer names
- `@($env:COMPUTERNAME)` - Default to local computer name
- `Position=0` - First positional parameter

```powershell
    [PSCredential]$Credential,
```
**Explanation**: 
- `[PSCredential]` - Secure credential object type
- No default value means it's optional
- Used for remote authentication

```powershell
    [ValidateRange(1,99)]
    [int]$ThresholdWarning = 20,
```
**Explanation**: 
- `[ValidateRange()]` - Built-in validation
- Prevents invalid values at parameter binding time
- Default of 20 means warning at <20% free space

```powershell
    [switch]$ShowOnlyProblems,
```
**Explanation**: 
- `[switch]` - Boolean parameter type
- Present = $true, Absent = $false
- No value needed when calling

---

## Functions Explained

### 1. Write-ColoredOutput Function

```powershell
function Write-ColoredOutput {
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
```

**Key Concepts**:
- **String Interpolation**: `"[$timestamp] $Message"` embeds variables in string
- **Conditional Logic**: `if/else` based on switch parameter
- **Default Parameters**: `$Color = "White"` provides fallback
- **Date Formatting**: `Get-Date -Format` for consistent timestamps

### 2. Get-LocalDiskSpace Function

```powershell
$drives = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop | 
    Where-Object { $_.Size -gt 0 }
```

**Key Concepts**:
- **CIM Instance**: Modern replacement for WMI
- **Pipeline**: `|` passes objects between commands
- **Filtering**: `Where-Object` filters out drives with no size
- **Error Handling**: `-ErrorAction Stop` makes errors terminating

```powershell
$driveInfo = $drives | ForEach-Object {
    $freePercent = if ($_.Size -gt 0) { 
        ($_.FreeSpace / $_.Size) * 100 
    } else { 
        0 
    }
```

**Key Concepts**:
- **Calculated Properties**: Computing values on-the-fly
- **Automatic Variable**: `$_` represents current pipeline object
- **Ternary-like Logic**: `if/else` in expression context
- **Division Protection**: Checking for zero to avoid divide-by-zero

```powershell
[PSCustomObject]@{
    ComputerName = $env:COMPUTERNAME
    Drive = $_.DeviceID
    'Total(GB)' = [math]::Round($_.Size / 1GB, 2)
}
```

**Key Concepts**:
- **PSCustomObject**: Creating custom objects for structured data
- **Hash Table Syntax**: `@{}` creates key-value pairs
- **Static Methods**: `[math]::Round()` calls .NET static method
- **Automatic Constants**: `1GB` equals 1073741824 bytes

### 3. Get-RemoteDiskSpace Function

```powershell
if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
    throw "Cannot reach computer: $ComputerName"
}
```

**Key Concepts**:
- **Network Testing**: `Test-Connection` is PowerShell's ping
- **Logical Operators**: `-not` negates boolean result
- **Quiet Mode**: `-Quiet` returns boolean instead of object
- **Exception Throwing**: `throw` generates terminating error

```powershell
$invokeParams = @{
    ComputerName = $ComputerName
    ErrorAction = 'Stop'
}

if ($Credential) {
    $invokeParams['Credential'] = $Credential
}
```

**Key Concepts**:
- **Splatting Preparation**: Building hash table for parameters
- **Conditional Parameter Addition**: Adding parameters only when needed
- **Hash Table Manipulation**: Adding keys dynamically

```powershell
Invoke-Command @invokeParams
```

**Key Concepts**:
- **Splatting**: `@` operator expands hash table into parameters
- **Remote Execution**: Runs script block on remote computer
- **Serialization**: Objects are serialized/deserialized for transport

---

## Advanced PowerShell Techniques

### 1. Pipeline Processing
```powershell
$drives | Where-Object { $_.Status -eq "CRITICAL" } | Format-Table -AutoSize
```
**Explanation**: 
- Objects flow left-to-right through pipeline
- Each command processes objects one at a time
- Memory efficient for large datasets

### 2. Calculated Properties
```powershell
'Free(%)' = [math]::Round($freePercent, 2)
```
**Explanation**: 
- Properties calculated at runtime
- Allows data transformation during object creation
- Useful for formatting and derived values

### 3. Switch Expressions
```powershell
Type = switch($_.DriveType) {
    2 { "Removable" }
    3 { "Local" }
    4 { "Network" }
    default { "Unknown" }
}
```
**Explanation**: 
- More elegant than if/elseif chains
- Returns value directly
- `default` handles unmatched cases

### 4. Here-Strings
```powershell
Write-Host @"
╔════════════════════════════════════════╗
║     DISK SPACE MONITORING TOOL        ║
╚════════════════════════════════════════╝
"@ -ForegroundColor Cyan
```
**Explanation**: 
- `@" ... "@` preserves formatting
- Useful for multi-line text
- Supports variable expansion

---

## WMI/CIM Classes Explained

### Win32_LogicalDisk Class

**Properties Used**:
- `DeviceID`: Drive letter (C:, D:, etc.)
- `Size`: Total size in bytes
- `FreeSpace`: Available space in bytes
- `DriveType`: Numeric drive type indicator
- `VolumeName`: Drive label
- `FileSystem`: File system type (NTFS, FAT32)

**DriveType Values**:
- 0: Unknown
- 1: No Root Directory
- 2: Removable Disk
- 3: Local Disk
- 4: Network Drive
- 5: Compact Disc
- 6: RAM Disk

### Win32_OperatingSystem Class

**Properties Used**:
- `Caption`: OS name and version
- `OSArchitecture`: 32-bit or 64-bit
- `LastBootUpTime`: System boot time

### Win32_ComputerSystem Class

**Properties Used**:
- `TotalPhysicalMemory`: RAM in bytes
- `Name`: Computer name
- `Domain`: Domain membership

---

## PowerShell Remoting Deep Dive

### How Invoke-Command Works

1. **Connection Establishment**:
   - Uses WS-Management protocol
   - Default port: 5985 (HTTP) or 5986 (HTTPS)
   - Kerberos authentication in domain environments

2. **Serialization Process**:
   ```powershell
   Local Object → XML Serialization → Network Transport → XML Deserialization → Remote Object
   ```

3. **Script Block Execution**:
   - Runs in new PowerShell process on remote machine
   - Has access to remote machine's resources
   - Returns serialized results

### Security Considerations

**Authentication Methods**:
- **Kerberos**: Default for domain environments
- **NTLM**: Fallback authentication
- **CredSSP**: Allows credential delegation (double-hop)

**Execution Context**:
- Runs under provided credentials
- Subject to remote machine's execution policy
- Logged in Windows Event Log

---

## Best Practices Demonstrated

### 1. Error Handling
```powershell
try {
    # Risky operation
    $drives = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop
}
catch {
    Write-ColoredOutput "Error: $_" -Color Red
    return @{ Success = $false; Error = $_.Exception.Message }
}
```
**Best Practice**: Always wrap risky operations in try/catch blocks

### 2. Structured Output
```powershell
return @{
    Success = $true
    DriveInfo = $driveInfo
    SystemInfo = $systemInfo
}
```
**Best Practice**: Return structured objects for easy processing

### 3. Parameter Validation
```powershell
[ValidateRange(1,99)]
[int]$ThresholdWarning = 20
```
**Best Practice**: Validate input at parameter level, not in code

### 4. Modular Functions
Each function has single responsibility:
- `Get-LocalDiskSpace`: Local disk checking
- `Get-RemoteDiskSpace`: Remote disk checking
- `Show-DiskSpaceReport`: Display formatting
- `Export-DiskSpaceReport`: Export functionality

**Best Practice**: Keep functions focused on single tasks

### 5. Progress Feedback
```powershell
Write-ColoredOutput "Connecting to remote computer: $ComputerName..." -Color Cyan
```
**Best Practice**: Provide user feedback for long-running operations

---

## Common Patterns and Idioms

### 1. Null-Coalescing Pattern
```powershell
$value = if ($condition) { $result } else { $default }
```

### 2. Pipeline With Calculated Properties
```powershell
Get-Process | Select-Object Name, @{N='Memory(MB)'; E={$_.WS/1MB}}
```

### 3. Splatting for Clean Code
```powershell
$params = @{
    Property1 = "Value1"
    Property2 = "Value2"
}
Command @params
```

### 4. Type Accelerators
```powershell
[math]::Round()  # System.Math
[PSCustomObject] # System.Management.Automation.PSObject
```

---

## Performance Considerations

### 1. CIM vs WMI
- **CIM** (used in local function): Newer, faster, uses WinRM
- **WMI** (used in remote function): Legacy, works on older systems

### 2. Filtering at Source
```powershell
Where-Object { $_.Size -gt 0 }  # Filter early in pipeline
```

### 3. Minimize Remote Calls
Script executes one remote call and processes all data locally

### 4. Efficient Object Creation
Using `[PSCustomObject]@{}` is faster than `New-Object PSObject`

---

## Troubleshooting Guide

### Common Issues

1. **Access Denied**:
   - Check user permissions
   - Verify local admin rights
   - Consider UAC implications

2. **WinRM Not Available**:
   ```powershell
   Enable-PSRemoting -Force
   ```

3. **Firewall Blocking**:
   ```powershell
   New-NetFirewallRule -Name "WinRM-HTTP-In-TCP" -DisplayName "WinRM HTTP" -Enabled True -Direction Inbound -Protocol TCP -LocalPort 5985
   ```

4. **Trusted Hosts Issue**:
   ```powershell
   Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*"
   ```

---

## Extension Ideas for Learning

1. **Add Email Alerting**:
   ```powershell
   if ($criticalDrives) {
       Send-MailMessage -To "admin@company.com" -Subject "Critical Disk Space Alert"
   }
   ```

2. **Add Database Logging**:
   ```powershell
   Invoke-SqlCmd -Query "INSERT INTO DiskSpace VALUES (...)"
   ```

3. **Add Graphical Dashboard**:
   Use Windows Forms or WPF for GUI

4. **Add Predictive Analysis**:
   Calculate fill rate and predict when disk will be full

5. **Add Automatic Cleanup**:
   ```powershell
   if ($freePercent -lt 5) {
       Clear-RecycleBin -Force
   }
   ```

---

## Learning Resources

### PowerShell Documentation
- [about_Functions_Advanced](https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions_advanced)
- [about_Remote](https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_remote)
- [about_CIM](https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_cim)

### Related Technologies
- WS-Management Protocol
- WinRM Service Architecture
- .NET Framework Integration
- COM Object Model

---

## Quiz Questions for Self-Testing

1. **What's the difference between CIM and WMI?**
   - Answer: CIM is newer, uses WinRM, standards-based; WMI is legacy, uses DCOM

2. **Why use `[PSCustomObject]` instead of hash tables?**
   - Answer: Provides object-oriented features, better performance, predictable property order

3. **What does the splatting operator (@) do?**
   - Answer: Expands hash table into named parameters for cmdlets

4. **How does PowerShell remoting serialize objects?**
   - Answer: Converts to XML (CLIXML format) for network transport

5. **What's the purpose of `[CmdletBinding()]`?**
   - Answer: Enables advanced function features like common parameters

---

## Conclusion

This script demonstrates professional PowerShell development practices including:
- Proper error handling
- Modular design
- Remote execution capabilities
- User-friendly output
- Performance optimization
- Security consciousness

By studying this script, you learn not just disk space monitoring, but fundamental PowerShell concepts applicable to any system administration task.
