#======================================================================================================================
#
#          FILE: rport-windows-update.ps1
#
#   DESCRIPTION: Bootstrap Rport update for Windows
#
#          BUGS: https://github.com/cloudradar-monitoring/rport/issues
#
#     COPYRIGHT: (c) 2021 by the CloudRadar Team,
#
#       LICENSE: MIT
#  ORGANIZATION: cloudradar GmbH, Potsdam, Germany (cloudradar.io)
#       CREATED: 01/10/2021
#        EDITED: 23/11/2021
#======================================================================================================================
#Requires -RunAsAdministrator
# Definition of command line parameters
Param(
# Use unstable version yes/no
    [Switch]$t,
# Enable scripts
    [Switch]$x,
# Disable scripts
    [Switch]$d,
# Show a help message
    [Switch]$h,
# Install or update tacoscript
    [Switch]$m,
# Force update
    [Switch]$f,
# Install a specific version
    [String]$v
)

if ($h) {
    Write-Host "Update the rport client.
Invoking without parameters updates to the latest stable version.

Parameters:
-t  Use the latest unstable version.
-x  Enable command and script execution without asking for confirmation.
-d  Disable command and script execution.
-v [version] Upgrade to the specified version.
-m  do not install or update tacoscript
-f  force update without comparing versions
"
    exit
}
# VAR_PLACEHOLDER
# INCLUDE functions.ps1
$release = If ($t) {
    "unstable"
}
Else {
    "stable"
}
$enableScripts = $null
$enableScripts = If ($x) {
    "true"
}
$enableScripts = If ($d) {
    "false"
}

$myLocation= (Get-Location).path
$configFile = 'C:\Program Files\rport\rport.conf'
$installDir = "$( $Env:Programfiles )\rport"
if (-Not(Test-Path "$( $installDir )\rport.exe")) {
    Write-Host "You don't have RPort installed. Nothing to do."
    exit 0
}
Set-Location $installDir
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if($f) {
    # If current version is set to 0 an update will always be forced
    Write-Host "* Forcing an update or redownload"
    $currentVersion = '0'
}
else {
    $versionString = (& 'C:\Program Files\rport\rport.exe' --version)
    $currentVersion = $( $versionString -split " " )[1]
}

if ($v) {
    # Set a specific version for the download url
    $url = "https://github.com/cloudradar-monitoring/rport/releases/download/$( $v )/rport_$( $v )_Windows_x86_64.zip"
    Write-Host "* Downloading  $( $url ) ."
}
else {
    $url = "https://downloads.rport.io/rport/$( $release )/?arch=Windows_x86_64&gt=$currentVersion"
}
$temp = 'C:\windows\temp\'
$downloadFile = $temp + "rport_Windows_x86_64.zip"

Write-Host ""
# Download the package
try { Invoke-WebRequest -Uri $url -OutFile $downloadFile }
catch {
    Write-Host "* Error: Download status code $( $_.Exception.Response.StatusCode.Value__ )"
    exit 1
}

If ((Get-Item $downloadFile).length -eq 0) {
    Write-Host "* No RPort update needed. You are on the latest $currentVersion version."
    Remove-Item $downloadFile
    # Install or update tacoscript
    if($m -eq $false) {
        Install-Tacoscript
    }
    Set-Location $myLocation
    exit 0
}
Write-Host "* Download finished and stored to $( $downloadFile ) ."

function ExtendConfig {
    Add-Content -Path $configFile -Value "[remote-scripts]
  enabled = $enableScripts"
}
function abortOnNoTerminal {
    if ([System.Environment]::UserInteractive) {
        return
    }
    Remove-Item -Path $downloadFile -Force
    $host.ui.WriteErrorLine('This script cannot run without a terminal because questions are asked.')
    $host.ui.WriteErrorLine("Execute with '-x' to enable remote script execution or ")
    $host.ui.WriteErrorLine("execute with '-d' to disable remote script execution.")
    exit 1
}
function askForScriptEnabling {
    abortOnNoTerminal
    do {
        $yesNo = Read-Host -prompt 'Do you want to enabale remote script execution? Y/N'
        if ( $yesNo.Tolower().StartsWith('y')) {
            $enableScripts = 'true'
            return
        }
        if ( $yesNo.ToLower().StartsWith('n')) {
            $enableScripts = 'false'
            return
        }
    } while ($true)
}
# Check if the config needs an update
if (Select-String -Path $configFile -Pattern "[remote-scripts]") {
    Write-Host "* Scripts are already configured. Not changing."
}
else {
    if ($null -eq $enableScripts) {
        askForScriptEnabling
    }
    ExtendConfig
}

# Extract the ZIP file
Write-Host "* Extracting Rport.exe to $temp"
if(Test-Path $( $temp + 'rport.example.conf' )) {
    Remove-Item $( $temp + 'rport.example.conf' ) -Force
}
if(Test-Path $( $temp + 'rport.exe' )) {
    Remove-Item $( $temp + 'rport.exe' ) -Force
}
Expand-Zip -Path $downloadFile -DestinationPath $temp
Remove-Item $downloadFile
Remove-Item $( $temp + 'rport.example.conf' )
$targetVersion = (& "$( $temp )/rport.exe" --version) -replace "version ",""
Write-Host "* New version will be $targetVersion."

function Enable-Monitoring {
    if ( (Get-Content $configFile) -match "^\[monitoring\]" ){
        Write-Host "* Monitoring already enabled."
        return
    }
    Add-Content -Path $configFile -Value "
[monitoring]
  ## The rport client can collect and report performance data of the operating system.
  ## https://oss.rport.io/docs/no17-monitoring.html
  ## Monitoring is enabled by default
  enabled = true
  ## How often (seconds) monitoring data should be collected.
  ## A value below 60 seconds will be overwritten by the hard-coded default of 60 seconds.
  # interval = 60
  ## RPort monitors the fill level of almost all volumes or mount points.
  ## Change the below defaults to include or exclude volumes or mount points from the monitoring.
  #fs_type_include = ['ext3','ext4','xfs','jfs','ntfs','btrfs','hfs','apfs','exfat','smbfs','nfs']
  ## List of excluded mount points or device letters
  #fs_path_exclude = []
  ## Example:
  # fs_path_exclude = ['/mnt/*','h:']
  ## Having fs_path_exclude_recurse = false the specified path
  ## must match a mountpoint or it will be ignored
  ## Having fs_path_exclude_recurse = true the specified path
  ## can be any folder and all mountpoints underneath will be excluded
  #fs_path_exclude_recurse = false
  ## To avoid monitoring of so-called mount binds,
  ## mount points are identified by the path and device name.
  ## Mountpoints pointing to the same device are ignored.
  ## What appears first in /proc/self/mountinfo is considered as the original.
  ## Applies only to Linux
  #fs_identify_mountpoints_by_device = true
  ## RPort monitors all running processes
  ## Process monitoring is enabled by default
  pm_enabled = true
  ## Monitor kernel tasks identified by process group 0
  #pm_enable_kerneltask_monitoring = true
  ## The process list is sorted by PID descending. Only the top N processes are monitored.
  #pm_max_number_monitored_processes = 500
  ## Monitor the bandwidth usage of the following maximum two network cards:
  ## 'net_lan' and 'net_wan'.
  ## You must specify the device name and the maximum speed in Megabits.
  ## On Windows use 'Get-Netadapter' to discover adapter names.
  ## Examples:
  ## net_lan = [ 'eth0' , '1000' ]
  ## net_wan = ['Ethernet0', '1000']
  #net_lan = ['', '1000']
  #net_wan = ['', '1000']"
}

function Invoke-Later {
    Param
    (
        [Parameter(Mandatory = $true)]
        [string] $ScriptBlock,
        [Parameter(Mandatory = $false)]
        [int] $Delay = 10,
        [Parameter(Mandatory = $false)]
        [string] $Description = "Background Task"
    )
    $taskName = 'Invoke-Later-' + (Get-Random)
    $taskFile = [System.Environment]::GetEnvironmentVariable('TEMP', 'Machine') + '\' + $taskName + '.ps1'
    $ScriptBlock.Split("`n") | ForEach-Object {
        if ($_) {
            $_.Trim() | Out-File -FilePath $taskFile -Append
        }
    }
    "Unregister-ScheduledTask -Taskname $( $taskName ) -Confirm:`$false" | Out-File -FilePath $taskFile -Append
    "Remove-Item `"$( $taskFile )`" -Force" | Out-File -FilePath $taskFile -Append
    $action = New-ScheduledTaskAction -Execute "powershell" -Argument "-ExecutionPolicy bypass -file $( $taskFile )"
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds($Delay)
    $principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
    $task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings
    Register-ScheduledTask $taskName -InputObject $task
    Write-Host "* Task `"$( $Description )`" [$( $taskFile )] scheduled."
    Write-Host "  It will be executed within $( $Delay ) seconds."
}

# Install or update tacoscript
if($m -eq $false) {
    Install-Tacoscript
}

# Activate monitoring
Enable-Monitoring
Enable-Network-Monitoring
# Discover Interpreters
Push-InterpretersToConfig

# Create a scheduled task to restart RPort.
Invoke-Later -Description "Restart RPort" -Delay 10 -ScriptBlock {
    Stop-Service rport
    Copy-Item 'C:\Windows\Temp\rport.exe' 'C:\Program Files\rport\rport.new'
    Move-Item 'C:\Program Files\rport\rport.new'  'C:\Program Files\rport\rport.exe' -Force
    Remove-Item 'C:\windows\temp\rport.exe' -Force
    Start-Service rport
}
Set-Location $myLocation

Write-Host "
#  Update of rport finished.
#
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#  Give us a star on https://github.com/cloudradar-monitoring/rport
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Thanks for using
  _____  _____           _
 |  __ \|  __ \         | |
 | |__) | |__) |__  _ __| |_
 |  _  /|  ___/ _ \| '__| __|
 | | \ \| |  | (_) | |  | |_
 |_|  \_\_|   \___/|_|   \__|
"