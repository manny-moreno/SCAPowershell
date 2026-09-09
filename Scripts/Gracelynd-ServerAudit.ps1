<#
.SYNOPSIS
    Gracelynd Server Readiness Audit

.DESCRIPTION
    Performs a basic health assessment of one or more Windows computers
    and produces a consolidated CSV report.

    Checks include:
    - Operating system
    - Uptime
    - CPU utilization
    - Memory utilization
    - Disk utilization
    - Critical services status
    - Overall health status

.AUTHOR
    Manny Moreno
#>

function Invoke-GracelyndServerAudit {
[CmdletBinding()]

param (
    [Parameter(Mandatory = $false)]
    [string[]]$ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false)]
    [int]$DiskWarningThreshold = 20,

    [Parameter(Mandatory = $false)]
    [int]$MemoryWarningThreshold = 85,

    [Parameter(Mandatory = $false)]
    [int]$CPUWarningThreshold = 85,

    [Parameter(Mandatory = $false)]
    [string[]]$CriticalServices = @(
        "WinRM",
        "W32Time"
    )
)

$results = @()

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Gracelynd Server Readiness Audit" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($computer in $ComputerName) {

    Write-Host "Auditing $computer..." -ForegroundColor Yellow

    try {

# Determine whether the target is the local computer
$isLocalComputer = (
    $computer -ieq $env:COMPUTERNAME -or
    $computer -ieq "localhost" -or
    $computer -eq "."
)

if ($isLocalComputer) {

    Write-Host "Using local CIM connection..." -ForegroundColor DarkGray

    # Retrieve local operating system information
    $os = Get-CimInstance `
        -ClassName Win32_OperatingSystem `
        -ErrorAction Stop

    # Retrieve local fixed disks
    $disks = Get-CimInstance `
        -ClassName Win32_LogicalDisk `
        -Filter "DriveType = 3" `
        -ErrorAction Stop

    # Retrieve local processor utilization
    $processors = Get-CimInstance `
        -ClassName Win32_Processor `
        -ErrorAction Stop

    # Retrieve monitored services
    $services = Get-CimInstance `
        -ClassName Win32_Service `
        -ErrorAction Stop
}
else {

    Write-Host "Using remote CIM connection..." -ForegroundColor DarkGray

    # Retrieve remote operating system information
    $os = Get-CimInstance `
        -ClassName Win32_OperatingSystem `
        -ComputerName $computer `
        -ErrorAction Stop

    # Retrieve remote fixed disks
    $disks = Get-CimInstance `
        -ClassName Win32_LogicalDisk `
        -ComputerName $computer `
        -Filter "DriveType = 3" `
        -ErrorAction Stop

    # Retrieve remote processor utilization
    $processors = Get-CimInstance `
        -ClassName Win32_Processor `
        -ComputerName $computer `
        -ErrorAction Stop

    #Retrieve monitored services
    $services = Get-CimInstance `
        -ClassName Win32_Service `
        -ComputerName $computer `
        -ErrorAction Stop
}

        # Calculate uptime
        $uptime = (Get-Date) - $os.LastBootUpTime

        # Calculate memory utilization
        $totalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)

        $freeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)

        $memoryUsedPercent = [math]::Round(
            (($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) /
            $os.TotalVisibleMemorySize) * 100,
            1
        )

        # Calculate average CPU utilization
        $cpuUsedPercent = [math]::Round(
            ($processors | Measure-Object -Property LoadPercentage -Average).Average,
            1
        )

        # Evaluate critical services
        $monitoredServices = $services |
            Where-Object { $_.Name -in $CriticalServices }

        $stoppedServices = $monitoredServices |
            Where-Object { $_.State -ne "Running" }

        $servicesChecked = @($monitoredServices).Count
        $servicesRunning = @(
                $monitoredServices |
                Where-Object { $_.State -eq "Running" }
        ).Count

        if (@($stoppedServices).Count -gt 0) {
            $stoppedServiceNames = (
                $stoppedServices |
                Select-Object -ExpandProperty Name
            ) -join ", "
        }
        else {
            $stoppedServiceNames = "None"
        }

        foreach ($disk in $disks) {

            $diskSizeGB = [math]::Round($disk.Size / 1GB, 2)
            $diskFreeGB = [math]::Round($disk.FreeSpace / 1GB, 2)

            $diskFreePercent = if ($disk.Size -gt 0) {
                [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1)
            }
            else {
                0
            }

            # Determine system health
            $healthStatus = "Healthy"

            # Critical conditions
            if (
                $diskFreePercent -lt 10 -or
                $memoryUsedPercent -ge 95 -or
                $cpuUsedPercent -ge 95
            ) {
                $healthStatus = "Critical"
            }

            # Warning conditions
            elseif (
                $diskFreePercent -lt $DiskWarningThreshold -or
                $memoryUsedPercent -gt $MemoryWarningThreshold -or
                $cpuUsedPercent -gt $CPUWarningThreshold -or
                @($stoppedServices).Count -gt 0
            ) {
                $healthStatus = "Warning"
            }

            $results += [PSCustomObject]@{
                ComputerName      = $computer
                OperatingSystem   = $os.Caption
                OSVersion         = $os.Version
                LastBootTime      = $os.LastBootUpTime
                UptimeDays        = $uptime.Days
                CPUUsedPercent    = $cpuUsedPercent
                TotalMemoryGB     = $totalMemoryGB
                FreeMemoryGB      = $freeMemoryGB
                MemoryUsedPercent = $memoryUsedPercent
                Drive             = $disk.DeviceID
                DiskSizeGB        = $diskSizeGB
                DiskFreeGB        = $diskFreeGB
                DiskFreePercent   = $diskFreePercent
                ServicesChecked   = $servicesChecked
                ServicesRunning   = $servicesRunning
                StoppedServices   = $stoppedServiceNames
                HealthStatus      = $healthStatus
                AuditTime         = Get-Date
                
            }
        }

        Write-Host "$computer completed successfully." -ForegroundColor Green
    }

    catch {

        Write-Host "Unable to audit $computer." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        $results += [PSCustomObject]@{
            ComputerName      = $computer
            OperatingSystem   = "ERROR"
            OSVersion         = $null
            LastBootTime      = $null
            UptimeDays        = $null
            TotalMemoryGB     = $null
            FreeMemoryGB      = $null
            MemoryUsedPercent = $null
            Drive             = $null
            DiskSizeGB        = $null
            DiskFreeGB        = $null
            DiskFreePercent   = $null
            CPUUsedPercent    = $null
            ServicesChecked   = $null
            ServicesRunning   = $null
            StoppedServices   = $null
            HealthStatus      = "Connection Failed"
            AuditTime         = Get-Date
        }
    }
}

Write-Host ""
Write-Host "System Summary" -ForegroundColor Cyan
Write-Host "--------------" -ForegroundColor Cyan

$systemSummary = $results |
    Group-Object ComputerName |
    ForEach-Object {

        $computerResults = $_.Group
        $firstResult = $computerResults | Select-Object -First 1
        
        if ($computerResults.HealthStatus -contains "Connection Failed") {
            $overallStatus = "Connection Failed"
        }
        elseif ($computerResults.HealthStatus -contains "Critical") {
            $overallStatus = "Critical"
        }
        elseif ($computerResults.HealthStatus -contains "Warning") {
            $overallStatus = "Warning"
        }
        else {
            $overallStatus = "Healthy"
        }

        [PSCustomObject]@{
            Computer = $_.Name
            Status = $overallStatus
            CPUPercent = $firstResult.CPUUsedPercent
            MemoryPercent = $firstResult.MemoryUsedPercent
            StoppedServices = $firstResult.StoppedServices
        }
    }

    $systemSummary |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "DISK SUMMARY" -ForegroundColor Cyan
    Write-Host "------------" -ForegroundColor Cyan

    $results |
        Where-Object { $null -ne $_.Drive } |
        Select-Object ComputerName, 
            Drive, 
            DiskFreeGB, 
            DiskFreePercent |
        Format-Table -AutoSize

# Create Reports folder if necessary
$reportFolder = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..\Reports")
)

if (-not (Test-Path $reportFolder)) {
    New-Item -ItemType Directory -Path $reportFolder | Out-Null
}


# Generate timestamped report filename
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$reportPath = Join-Path `
    $reportFolder `
    "ServerAudit-$timestamp.csv"


# Export report
$results |
    Export-Csv `
        -Path $reportPath `
        -NoTypeInformation


Write-Host ""
Write-Host "Audit complete." -ForegroundColor Green
Write-Host "Report saved to:" -ForegroundColor Green
Write-Host $reportPath
}