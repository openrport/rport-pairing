$release = If ($t)
{
    "unstable"
}
Else
{
    "stable"
}
$myLocation = (Get-Location).path
$url = "https://downloads.rport.io/rport/$( $release )/latest.php?arch=Windows_x86_64"
$downloadFile = "C:\Windows\temp\rport_$( $release )_Windows_x86_64.zip"
$installDir = "$( $Env:Programfiles )\rport"
$dataDir = "$( $installDir )\data"

# Check if RPor is already installed
if (Test-Path $installDir)
{
    Write-Output "RPort is already installed."
    Write-Output "Download and execute the update script."
    Write-Output "Try the following:"
    Write-Output 'cd $env:temp
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url="https://pairing.rport.io/update"
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
    if ([int]$_.Exception.Response.StatusCode -eq 404)
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
if (-not(Test-Path $downloadFile -PathType leaf))
{
    Write-Output "* Downloading  $( $url ) ."
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $downloadFile
    Write-Output "* Download finished and stored to $( $downloadFile ) ."
}

# Create a directory
mkdir $installDir| Out-Null
mkdir $dataDir| Out-Null


# Extract the ZIP file
Expand-Zip -Path $downloadFile -DestinationPath $installDir
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
$configContent = $configContent -replace '#id = .*', "id = `"$( (Get-CimInstance -Class Win32_ComputerSystemProduct).UUID )`""
$configContent = $configContent -replace '#fingerprint = .*', "fingerprint = `"$( $fingerprint )`""
$configContent = $configContent -replace 'log_file = .*', "log_file = '$( $logFile )'"
$configContent = $configContent -replace '#name = .*', "name = `"$( $env:computername )`""
$configContent = $configContent -replace '#data_dir = .*', "data_dir = '$( $dataDir )'"
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
$tags = @()
# Get the location of the server
$geoUrl = "http://ip-api.com/json/?fields=status,country,city"
$geoData = Invoke-RestMethod -Uri $geoUrl
if ("success" -eq $geoData.status)
{
    # Add geo data as tags
    $tags += $geoData.country
    $tags += $geoData.city
}
if ($g)
{
    # Add a custom tag
    $tags += $g
}
if ($tags.Length -gt 0)
{
    $tagsLine = "tags = [`""
    $tagsLine += $tags -join "`",`""
    $tagsLine += "`"]"
    $configContent = $configContent -replace '#tags = .*', $tagsLine
}
$configContent = Enable-Network-Monitoring -ConfigContent $configContent
$configContent = Enable-InterpreterAlias -ConfigContent $configContent

# Finally, write the config to a file
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[IO.File]::WriteAllLines($configFile, $configContent, $Utf8NoBomEncoding)

if ($d)
{
    # Exit here
    Write-Output "Configuration written to $( $configFile )."
    Write-Output "==================================================================================="
    Get-Content $configFile -Raw
    Write-Output "==================================================================================="
    Write-Output "Exit! Service not installed."
    exit 0
}

# Register the service
if (-not(Get-Service rport -erroraction 'silentlycontinue'))
{
    Write-Output ""
    Write-Output "* Registering rport as a windows service."
    & "$( $installDir )\rport.exe" --service install --config $configFile
}
else
{
    Stop-Service -Name rport
}
Start-Service -Name rport
Get-Service rport

if ($i)
{
    Install-Tacoscript
}

# Create an uninstaller script for rport
Set-Content -Path "$( $installDir )\uninstall.bat" -Value 'echo off
echo off
net session > NUL
IF %ERRORLEVEL% EQU 0 (
    ECHO You are Administrator. Fine ...
) ELSE (
    ECHO You are NOT Administrator. Exiting...
    PING -n 5 127.0.0.1 > NUL 2>&1
    EXIT /B 1
)
echo Removing rport now
ping -n 5 127.0.0.1 > null
sc stop rport
"%PROGRAMFILES%"\rport\rport.exe --service uninstall -c "%PROGRAMFILES%"\rport\rport.conf
cd C:\
rmdir /S /Q "%PROGRAMFILES%"\rport\
echo Rport removed
ping -n 2 127.0.0.1 > null
'
Write-Output ""
Write-Output "* Uninstaller created in $( $installDir )\uninstall.bat."
# Clean Up
Remove-Item $downloadFile



function Finish
{
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
#  READ THE DOCS ON https://kb.rport.io/
#
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#  Give us a star on https://github.com/cloudradar-monitoring/rport
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
#

Thanks for using
  _____  _____           _
 |  __ \|  __ \         | |
 | |__) | |__) |__  _ __| |_
 |  _  /|  ___/ _ \| '__| __|
 | | \ \| |  | (_) | |  | |_
 |_|  \_\_|   \___/|_|   \__|
"
}

function Fail
{
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

4) Request support on https://github.com/cloudradar-monitoring/rport-pairing/discussions/categories/help-needed
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