Get-EventLog -LogName System -Newest 3

Get-CimInstance Win32_OperatingSystem |
   Select-Object CSName, Caption, Version, LastBootUpTime

Get-CimInstance Win32_LogicalDisk -Filter "DriveType = 3" |
   Select-Object DeviceID, Size, FreeSpace

Get-ADComputer -Filter * |
   Select-Object Name

Get-CimInstance Win32_OperatingSystem -ComputerName LON-DC1 |
   Select-Object CSName, Caption, Version, LastBootUpTime

Get-CimInstance Win32_OperatingSystem -ComputerName LON-SVR1 |
   Select-Object CSName, Caption, Version, LastBootUpTime
