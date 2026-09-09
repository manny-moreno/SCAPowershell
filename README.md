# SCAPowershell

## Gracelynd Server Readiness Audit

A PowerShell-based Windows infrastructure assessment tool developed as part of the Microsoft Software & Systems Academy (MSSA) Automating Administration with Windows PowerShell project.

The project provides a reusable PowerShell function that automates the collection and evaluation of common Windows system health indicators across one or more computers and produces both an administrator-friendly console summary and a timestamped CSV report.

## Business Scenario

IT administrators frequently need to evaluate the health and readiness of multiple Windows computers. Manually checking each system for processor utilization, memory utilization, available disk space, service status, and other system information can be repetitive and time-consuming.

The Gracelynd Server Readiness Audit demonstrates how PowerShell can automate this process and consolidate the results into a repeatable assessment.

This project also serves as a prototype for a potential Gracelynd & Company infrastructure assessment capability.

## What the Script Checks

The audit collects and evaluates:

- Operating system and version
- Last boot time and uptime
- CPU utilization
- Memory utilization
- Fixed-disk capacity and available space
- Critical Windows service status
- Overall system health

By default, the following services are monitored:

- Windows Remote Management (`WinRM`)
- Windows Time (`W32Time`)

## PowerShell Function

The audit is implemented as an advanced PowerShell function:

`Invoke-GracelyndServerAudit`

The function accepts parameters that allow an administrator to specify target computers, health thresholds, and critical Windows services without modifying the underlying script.

## Health Classification

Each audited system is classified as:

**Healthy**  
No monitored condition exceeds the configured warning or critical thresholds.

**Warning**  
One or more warning thresholds are exceeded, or a monitored critical service is not running.

**Critical**  
One or more critical CPU, memory, or disk conditions are detected.

**Connection Failed**  
The target computer could not be successfully audited.

## Local and Remote Auditing

The script supports both local and remote Windows computers.

For the local computer, the script uses a local CIM connection.

For remote computers, the script uses PowerShell CIM commands with the `-ComputerName` parameter.

This allows multiple Windows computers to be evaluated during a single execution.

## Parameters

### ComputerName

Specifies one or more computers to audit.

If no computer is specified, the script defaults to the local computer.

### DiskWarningThreshold

Specifies the minimum percentage of free disk space before a warning is generated.

Default:

```text
20%
```

### MemoryWarningThreshold

Specifies the memory utilization percentage that generates a warning.

Default:

```text
85%
```

### CPUWarningThreshold

Specifies the CPU utilization percentage that generates a warning.

Default:

```text
85%
```

### CriticalServices

Specifies the Windows services that should be monitored.

Default:

```text
WinRM
W32Time
```

## Usage

### Load the Function

Before running the audit, dot-source the PowerShell script to load the function into the current PowerShell session:

```powershell
. .\Scripts\Gracelynd-ServerAudit.ps1
```

Verify that the function is available:

```powershell
Get-Command Invoke-GracelyndServerAudit
```

### Audit the Local Computer

```powershell
Invoke-GracelyndServerAudit
```

### Audit Multiple Computers

```powershell
Invoke-GracelyndServerAudit `
    -ComputerName LON-CL1,LON-DC1,LON-SVR1
```

### Specify Critical Services

By default, the audit monitors WinRM and Windows Time (`W32Time`). Administrators can override the monitored services through the `CriticalServices` parameter.

For example:

```powershell
Invoke-GracelyndServerAudit `
    -ComputerName LON-CL1,LON-DC1,LON-SVR1 `
    -CriticalServices W32Time
```

### Customize Health Thresholds

The audit also supports configurable warning thresholds for disk space, memory utilization, and CPU utilization.

Example:

```powershell
Invoke-GracelyndServerAudit `
    -ComputerName LON-CL1,LON-DC1,LON-SVR1 `
    -DiskWarningThreshold 25 `
    -MemoryWarningThreshold 80 `
    -CPUWarningThreshold 80
```

## Console Output

The script produces two administrator-facing summaries.

### System Summary

Provides one consolidated record per computer showing:

- Overall health status
- CPU utilization
- Memory utilization
- Stopped monitored services

Example:

```text
Computer Status  CPUPercent MemoryPercent StoppedServices
-------- ------  ---------- ------------- ---------------
LON-CL1  Warning       2.00         60.90 WinRM
LON-DC1  Healthy       0.00         37.90 None
LON-SVR1 Healthy       0.00         31.50 None
```

### Disk Summary

Provides disk-level information separately:

```text
ComputerName Drive DiskFreeGB DiskFreePercent
------------ ----- ---------- ---------------
LON-CL1      C:         84.07           66.50
LON-CL1      E:        126.90           99.90
LON-DC1      C:        111.26           88.00
```

## CSV Reporting

Every successful execution creates a timestamped CSV report in the `Reports` directory.

Example:

```text
Reports\ServerAudit-20260909-135719.csv
```

The CSV preserves detailed system and disk information for further analysis, documentation, or future automation.

Generated audit reports are excluded from source control so operational output is not committed to the repository.

## Technologies and PowerShell Concepts

This project demonstrates the use of:

- PowerShell scripting
- Parameters
- Variables
- Arrays
- `foreach` loops
- Conditional logic
- `try` / `catch` error handling
- PowerShell pipelines
- CIM / WMI
- `Get-CimInstance`
- `Where-Object`
- `Select-Object`
- `Measure-Object`
- `Group-Object`
- `PSCustomObject`
- CSV export
- File and path management
- Local and remote Windows administration
- Git and GitHub source control

## Project Structure

```text
SCAPowershell/
├── Scripts/
│   ├── Events.ps1
│   └── Gracelynd-ServerAudit.ps1
├── Reports/
├── .gitignore
└── README.md
```

`Events.ps1` contains course/lab work.

`Gracelynd-ServerAudit.ps1` contains the server readiness audit project.

The `Reports` directory is used for generated CSV audit results.

## MSSA Project Requirements Demonstrated

This project demonstrates:

- PowerShell pipelines
- CIM-based Windows system administration
- Data filtering and manipulation
- Readable and color-coded console output
- Parameterized user input
- Multi-computer administration
- Loops and conditional logic
- Error handling with try/catch
- Progress and status messages
- CSV report generation
- Reusable advanced PowerShell function

The project also demonstrates the bonus challenge of converting the administrative script into a reusable function.

## Potential Business Application

The current implementation is a prototype developed in a controlled lab environment.

A production implementation could serve as the foundation for a repeatable infrastructure readiness or health assessment. Future development could include centralized configuration, scheduled execution, historical trend analysis, additional Windows services, alerting, dashboards, and integration with other automation or management platforms.

The underlying goal is to reduce repetitive administrative work while presenting system information in a form that allows an administrator to focus on exceptions requiring judgment or action.

## Author

Manny Moreno
