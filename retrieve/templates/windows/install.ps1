$release = If ($t)
{
    "unstable"
}
Else
{
    "stable"
}
$myLocation = (Get-Location).path
$installDir = "$( $Env:Programfiles )\rport"
$dataDir = "$( $installDir )\data"

# Check if RPort is already installed
if (Test-Path $installDir)
{
    Write-Output "RPort is already installed."
    Write-Output "Download and execute the update script."
    Write-Output "Try the following:"
    Write-Output 'cd $env:temp
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url="https://pairing.openrport.io/update"
Invoke-WebRequest -Uri $url -OutFile "rport-update.ps1"
powershell -ExecutionPolicy Bypass -File .\rport-update.ps1
rm .\rport-update.ps1 -Force
'
    exit
}

# Test the connection to the RPort server first
$test_response = $null
try
{
    $test_response = (Invoke-WebRequest -Uri $connect_url -Method Head -TimeoutSec 2).BaseResponse
}
catch
{
    $status = [int]$_.Exception.Response.StatusCode
    if ($status -lt 500)
    {
        Write-Output "* Testing connection to $( $connect_url ) has succeeded."
    }
    else
    {
        $fc = $host.UI.RawUI.ForegroundColor
        $host.UI.RawUI.ForegroundColor = "red"
        $test_response
        Write-Output "# Testing connection to $( $connect_url ) has failed."
        $_.Exception.Message
        $host.UI.RawUI.ForegroundColor = $fc
        exit 1
    }
}
# Download the package from GitHub
$downloadFile = Invoke-Download -pkgUrl $pkgUrl
Write-Information "* Download finished and stored to $( $downloadFile )."
# Install
if ($downloadFile -match '\.zip$')
{
    Write-Output "* Installing from ZIP ..."
    # Create a directory
    mkdir $installDir| Out-Null
    mkdir $dataDir| Out-Null
    # Extract the ZIP file
    Expand-Zip -Path $downloadFile -DestinationPath $installDir
    # Create an uninstaller script
    New-Uninstaller
    $InstallMethod = 'zip'
}
elseif ($downloadFile -match '\.msi$')
{
    # Install the MSI
    Write-Output "* Installing MSI ..."
    $msiLog = "$( $downloadFile )-install.log"
    Start-Process msiexec.exe -Wait -ArgumentList "/i $( $downloadFile ) /qn /quiet /log $( $msiLog )"
    Write-Output "* MSI installed. Log saved to $( $msiLog )"
    $InstallMethod = 'msi'
}
else
{
    Write-Error "Unrecognized file extension for $( $downloadFile )"
}
Write-Output "* RPort installed via $InstallMethod"
$targetVersion = (& "$( $installDir )/rport.exe" --version) -replace "version ", ""
Write-Output "* RPort Client version $targetVersion installed."
$configFile = "$( $installDir )\rport.conf"

# Create a config file from the example
$configContent = Get-Content "$( $installDir )\rport.example.conf" -Encoding utf8
Write-Output "* Creating new configuration file $( $configFile )."
# Put variables into the config
$logFile = "$( $installDir )\rport.log"
$configContent = $configContent -replace 'server = .*', "server = `"$( $connect_url )`""
$configContent = $configContent -replace '.*auth = .*', "  auth = `"$( $client_id ):$( $password )`""
$configContent = $configContent -replace '#fingerprint = .*', "fingerprint = `"$( $fingerprint )`""
$configContent = $configContent -replace 'log_file = .*', "log_file = '$( $logFile )'"
$configContent = $configContent -replace '#data_dir = .*', "data_dir = '$( $dataDir )'"
# Set the system UUID
# For the time beeing creating the ID from the PowerShell is more reliable
$HostUUID = Get-HostUUID
$configContent = $configContent -replace '#id = .*', "id = `"$( $HostUUID )`""
$configContent = $configContent -replace 'use_system_id = true', 'use_system_id = false'
if ($x)
{
    # Enable commands and scripts
    $configContent = $configContent -replace '#allow = .*', "allow = ['.*']"
    $configContent = $configContent -replace '#deny = .*', "deny = []"
    $configContent = $configContent -replace '\[remote-scripts\]', "$&`n  enabled = true"
}
else
{
    # Disbale commands
    $configContent = Set-TomlVar -ConfigContent $configContent -Block "remote-commands" -Key "enabled" -Value "false"
}
# Enable/Disable file reception
$configContent = Enable-FileReception -ConfigContent $configContent -Switch $r
$attributes = @{
    'tags' = @()
    'labels' = @{}
}
# Get the location of the server
$geoUrl = "http://ip-api.com/json/?fields=status,country,city"
try
{
    $geoData = Invoke-RestMethod -Uri $geoUrl -TimeoutSec 5
    if ("success" -eq $geoData.status)
    {
        # Add geo data as tags
        $attributes.labels.country = $geoData.country
        $attributes.labels.city = $geoData.city
    }
}
catch
{
    Write-Output ": Fetching geodata failed. Skipping"
}

if ($g)
{
    # Add a custom tag
    $attributes.tags += $g
}
$configContent = Set-TomlVar -ConfigContent $configContent `
  -Block "client" `
  -Key "attributes_file_path" `
  -Value "'C:\Program Files\rport\client_attributes.json'"
[IO.File]::WriteAllLines("C:\Program Files\rport\client_attributes.json", ($attributes|ConvertTo-Json))
$configContent = Enable-Network-Monitoring -ConfigContent $configContent
$configContent = Enable-InterpreterAlias -ConfigContent $configContent

# Finally, write the config to a file
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[IO.File]::WriteAllLines($configFile, $configContent, $Utf8NoBomEncoding)

if ($d)
{
    # in debug mode, exit here if
    Write-Output "Configuration written to $( $configFile )."
    Write-Output "==================================================================================="
    Get-Content $configFile -Raw
    Write-Output "==================================================================================="
    Write-Output "Exit! Service not installed."
    exit 0
}

if (-not(Get-Service rport -erroraction 'silentlycontinue'))
{
    # Register the service
    Write-Output ""
    Write-Output "* Registering rport as a windows service."
    & "$( $installDir )\rport.exe" --service install --config $configFile
    # Set the service startup and recovery actions
    Optimize-ServiceStartup
}
else
{
    Stop-Service -Name rport
}
Start-Service -Name rport
Get-Service rport

if ($i)
{
    try
    {
        Install-Tacoscript
    }
    catch
    {
        Write-Output ": Installation of Tacoscript failed"
        Write-Output $_
    }
}
# Clean Up
Remove-Item $downloadFile
if ($msiLog -And (Test-Path $msiLog))
{
    Remove-Item $msiLog -Force
}

function Finish
{
    Get-Log
    Set-Location $myLocation
    Write-Output "#
#
#  Installation of rport finished.
#
#  This client is now connected to $( $connect_url )
#
#  Look at $( $configFile ) and explore all options.
#  Logs are written to $( $installDir )/rport.log.
#
#  READ THE DOCS ON https://kb.openrport.io/
#
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#  Give us a star on https://github.com/openrport/openrport
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
#

Thanks for using
   ____                   _____  _____           _
  / __ \                 |  __ \|  __ \         | |
 | |  | |_ __   ___ _ __ | |__) | |__) |__  _ __| |_
 | |  | | '_ \ / _ \ '_ \|  _  /|  ___/ _ \| '__| __|
 | |__| | |_) |  __/ | | | | \ \| |  | (_) | |  | |_
  \____/| .__/ \___|_| |_|_|  \_\_|   \___/|_|   \__|
        | |
        |_|
"
}

function Fail
{
    Get-Log
    Write-Output "
#
# -------------!!   ERROR  !!-------------
#
# Installation of rport finished with errors.
#

Try the following to investigate:
1) sc query rport

2) open C:\Program Files\rport\rport.log

3) READ THE DOCS on https://kb.rport.io

4) Request support on https://github.com/openrport/rport-pairing/discussions/categories/help-needed
"
}

if ($Null -eq (get-process "rport" -ea SilentlyContinue))
{
    Fail
}
else
{
    Finish
}