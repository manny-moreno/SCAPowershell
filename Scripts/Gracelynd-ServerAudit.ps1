<#
.SYNOPSIS
    Gracelynd Server Readiness Audit

.DESCRIPTION
    Performs a basic health assessment of one or more Windows computers
    and produces a consolidated CSV report.

    Checks include:
    - Operating system
    - Uptime
    - Memory utilization
    - Disk utilization
    - Overall health status

.AUTHOR
    Manny Moreno
#>

param (
    [Parameter(Mandatory = $false)]
    [string[]]$ComputerName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false)]
    [int]$DiskWarningThreshold = 20,

    [Parameter(Mandatory = $false)]
    [int]$MemoryWarningThreshold = 85
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

        # Retrieve operating system information
        $os = Get-CimInstance `
            -ClassName Win32_OperatingSystem `
            -ComputerName $computer `
            -ErrorAction Stop

        # Retrieve local fixed disks
        $disks = Get-CimInstance `
            -ClassName Win32_LogicalDisk `
            -ComputerName $computer `
            -Filter "DriveType = 3" `
            -ErrorAction Stop

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

            if (
                $diskFreePercent -lt $DiskWarningThreshold -or
                $memoryUsedPercent -gt $MemoryWarningThreshold
            ) {
                $healthStatus = "Warning"
            }

            $results += [PSCustomObject]@{
                ComputerName      = $computer
                OperatingSystem   = $os.Caption
                OSVersion         = $os.Version
                LastBootTime      = $os.LastBootUpTime
                UptimeDays        = $uptime.Days
                TotalMemoryGB     = $totalMemoryGB
                FreeMemoryGB      = $freeMemoryGB
                MemoryUsedPercent = $memoryUsedPercent
                Drive             = $disk.DeviceID
                DiskSizeGB        = $diskSizeGB
                DiskFreeGB        = $diskFreeGB
                DiskFreePercent   = $diskFreePercent
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
            HealthStatus      = "Connection Failed"
            AuditTime         = Get-Date
        }
    }
}

Write-Host ""
Write-Host "Audit Results" -ForegroundColor Cyan
Write-Host "-------------" -ForegroundColor Cyan

$results |
    Select-Object ComputerName,
                  Drive,
                  UptimeDays,
                  MemoryUsedPercent,
                  DiskFreePercent,
                  HealthStatus |
    Format-Table -AutoSize


# Create Reports folder if necessary
$reportFolder = Join-Path $PSScriptRoot "..\Reports"

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
