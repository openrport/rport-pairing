$InformationPreference = "continue"
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues = @{ '*:Encoding' = 'utf8' }
trap
{
    "
#
# -------------!!   ERROR  !!-------------
#
# Installation or updare of rport finished with errors.
#

Error in line $( $_.InvocationInfo.ScriptLineNumber )
    $_

Try the following to investigate:
1) sc query rport

2) open C:\Program Files\rport\rport.log

3) READ THE DOCS on https://kb.openrport.io

4) Request support on https://github.com/openrport/rport-pairing/discussions/categories/help-needed
"
    Set-Location $myLocation
    exit 1
}

$InstallerLogFile = $false
if (-not(Get-Command Write-Information -erroraction silentlycontinue))
{
    $InstallerLogFile = (Get-Location).path + "\rport-installer.log"
    if (Test-Path $InstallerLogFile)
    {
        Remove-Item $InstallerLogFile
    }
    Write-Output "# Compatibility mode for PowerShell $( $PSVersionTable.PSVersion ) activated"
    Write-Output "# All information stream messages are redirected to $( $InstallerLogFile )"
    function Write-Information
    {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Applies only to old PS Versions')]
        Param(
            [parameter(Mandatory = $false)]
            [String] $MessageData = ""
        )
        Add-Content -Path $InstallerLogFile -Value $MessageData
    }
}

function Get-Log
{
    if (Test-Path $InstallerLogFile)
    {
        Write-Output ""
        Write-Output "= The following information has been logged:"
        Get-Content $InstallerLogFile
        Remove-Item $InstallerLogFile -Force
    }
}

# Extract a ZIP file
function Expand-Zip
{
    Param(
        [parameter(Mandatory = $true)]
        [String] $Path,
        [parameter(Mandatory = $true)]
        [String] $DestinationPath
    )
    if (Get-Command Expand-Archive -errorAction SilentlyContinue)
    {
        Expand-Archive -Path $Path -DestinationPath $DestinationPath -force
    }
    else
    {
        # Use a fallback for old powershells < 5
        Remove-Item (-join ($DestinationPath, "\*")) -force -Recurse
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $DestinationPath)
    }
}

function Add-ToConfig
{
    [OutputType([String])]
    Param(
        [Parameter(Mandatory)]
        [Object[]]$ConfigContent,
        [parameter(Mandatory = $true)]
        [String] $Block,
        [parameter(Mandatory = $true)]
        [String] $Line
    )
    <#
    .SYNOPSIS
        Add a line to a block of a the rport toml configuration.
    #>
    if ($configContent -NotMatch "\[$block\]")
    {
        # Append the block if missing
        $configContent = "$configContent`n`n[$block]"
    }
    Write-Information "* Adding `"$Line`" to [$Block]"
    $configContent = $configContent -replace "\[$Block\]", "$&`n  $Line"
    $configContent
}

function Find-Interpreter
{
    <#
    .SYNOPSIS
        Find common script interpreters installed on the system
    #>
    $interpreters = @{
    }
    if (Test-Path -Path 'C:\Program Files\PowerShell\7\pwsh.exe')
    {
        $interpreters.add('powershell7', 'C:\Program Files\PowerShell\7\pwsh.exe')
    }
    if (Test-Path -Path 'C:\Program Files\Git\bin\bash.exe')
    {
        $interpreters.add('bash', 'C:\Program Files\Git\bin\bash.exe')
    }
    $interpreters
}

function Enable-FileReception
{
    [OutputType([String])]
    param (
        [Parameter(Mandatory)]
        [Object[]]$ConfigContent,
        [Parameter(Mandatory)]
        [Boolean]$Switch
    )

    if ($Switch)
    {
        try
        {
            $ConfigContent = Set-TomlVar -ConfigContent $ConfigContent "file-reception" -Key "enabled" -value "true"
            Write-Information "* File reception has been enabled."
        }
        catch
        {
            Write-Information ": Enabling file-reception failed."
            Write-Information ": Check the settings of [file-reception] manually and change to your needs."
        }

    }
    else
    {
        try
        {
            $ConfigContent = Set-TomlVar -ConfigContent $ConfigContent "file-reception" -Key "enabled" -value "false"
            Write-Information "* File reception has been disabled."
        }
        catch
        {
            Write-Information ": Disabling file-reception failed."
            Write-Information ": Check the settings of [file-reception] manually and change to your needs."
        }

    }


    $ConfigContent
    return
}

function Enable-InterpreterAlias
{
    <#
    .SYNOPSIS
        Push interpreters to the rport.conf
    #>
    [OutputType([Object[]])]
    param (
        [Parameter(Mandatory)]
        [Object[]]$ConfigContent
    )

    Write-Information "* Looking for script interpreters."
    $interpreters = Find-Interpreter
    Write-Information "* $( $interpreters.count ) script interpreters found."
    if ($interpreters.count -eq 0)
    {
        $ConfigContent
        return
    }
    $interpreters.keys|ForEach-Object {
        $key = $_
        $value = $interpreters[$_]
        if (Test-TomlKeyExist -ConfigContent $ConfigContent -Block "interpreter-aliases" -Key $key)
        {
            Write-Information ": $key already present in configuration."
        }
        else
        {
            $ConfigContent = Add-ToConfig -ConfigContent $configContent -Block "interpreter-aliases" -Line "$( $key ) = '$( $value )'"
        }
    }
    $configContent
}

# Update Tacoscript
function Install-Tacoupdate
{
    $Temp = [System.Environment]::GetEnvironmentVariable('TEMP', 'Machine')
    $tacoUpdate = $Temp + '\tacoupdate.zip'
    Set-Location $Temp
    if ((Out-String -InputObject (& 'C:\Program Files\tacoscript\bin\tacoscript.exe' --version)) -match "Version: (.*)")
    {
        $tacoVersion = $matches[1].trim()
        $tacoUpdateUrl = "https://downloads.openrport.io/tacoscript/$( $release )/?arch=Windows_x86_64&gt=$tacoVersion"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $tacoUpdateUrl -OutFile $tacoUpdate -UseBasicParsing
        If ((Get-Item tacoupdate.zip).length -eq 0)
        {
            Write-Output "* No Tacoscript update needed. You are on the latest $tacoVersion version."
            Remove-Item tacoupdate.zip -Force
            return
        }
        $dest = "C:\Program Files\tacoscript"
        Expand-Zip -Path $tacoUpdate -DestinationPath $dest
        Move-Item "$( $dest )\tacoscript.exe" "$( $dest )\bin" -Force
        Write-Output "* Tacoscript updated to $( (& "$( $dest )\bin\tacoscript.exe" --version) -match "Version" )"
        Remove-Item $tacoUpdate -Force|Out-Null
    }
}

# Install Tacoscript
function Install-Tacoscript
{
    $tacoDir = "C:\Program Files\tacoscript"
    $tacoBin = $tacoDir + '\bin\tacoscript.exe'
    if (Test-Path -Path $tacoBin)
    {
        Write-Output "* Tacoscript already installed to $( $tacoBin )"
        Install-Tacoupdate
        return
    }
    $Temp = [System.Environment]::GetEnvironmentVariable('TEMP', 'Machine')
    Set-Location $Temp
    $url = "https://download.openrport.io/tacoscript/$( $release )/?arch=Windows_x86_64"
    $file = $temp + "\tacoscript.zip"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
    Write-Output "* Tacoscript dowloaded to $( $file )"
    New-Item -ItemType Directory -Force -Path "$( $tacoDir )"|Out-Null
    Expand-Zip -Path $file -DestinationPath $tacoDir
    New-Item -ItemType Directory -Force -Path "$( $tacoDir )\bin"|Out-Null
    Move-Item "$( $tacoDir )\tacoscript.exe" "$( $tacoDir )\bin\"
    $ENV:PATH = "$ENV:PATH;$( $tacoDir )\bin"

    [Environment]::SetEnvironmentVariable(
            "Path",
            [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine) + ";$( $tacoDir )\bin",
            [EnvironmentVariableTarget]::Machine
    )
    Write-Output "* Tacoscript installed to '$( $tacoDir )' $( (tacoscript.exe --version) -match "Version" )"
    Remove-Item $file -force
    # Create an uninstaller script for Tacoscript
    Set-Content -Path "$( $tacoDir )\uninstall.bat" -Value 'echo off
echo off
net session > NUL
IF %ERRORLEVEL% EQU 0 (
    ECHO You are Administrator. Fine ...
) ELSE (
    ECHO You are NOT Administrator. Exiting...
    PING -n 5 127.0.0.1 > NUL 2>&1
    EXIT /B 1
)
echo Removing Tacoscript now
ping -n 5 127.0.0.1 > null
rmdir /S /Q "%PROGRAMFILES%"\tacoscript\
echo Tacoscript removed
ping -n 2 127.0.0.1 > null
'
    Write-Output "* Tacoscript uninstaller created in $( $tacoDir )\uninstall.bat."
}

function Test-TomlKeyExist
{
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory)]
        [Object[]]$ConfigContent,
        [Parameter(Mandatory)]
        [String]$Block,
        [Parameter(Mandatory)]
        [String]$Key
    )
    if (-not$ConfigContent -match [Regex]::Escape("^[$( $Block )]"))
    {
        $ConfigContent
        Write-Error "Block [$( $Block )] not found in config content"
        $false
        return
    }
    $inBlock = $false
    foreach ($Line in $ConfigContent -split "`n")
    {
        if ($Line -match "^\[$( $Block )\]")
        {
            $inBlock = $true
        }
        elseif ($Line -match "^\[.*\]")
        {
            $inBlock = $false
        }
        if ($inBlock -and ($line -match "$key = ") -and ($line -notmatch "#.*$key ="))
        {
            $true
            return
        }
    }
    $false
    return
}

function Set-TomlVar
{
    [OutputType([String])]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [Object[]]$ConfigContent,
        [Parameter(Mandatory)]
        [String]$Block,
        [Parameter(Mandatory)]
        [String]$Key,
        [Parameter(Mandatory)]
        [String]$Value
    )
    if (-not$ConfigContent -match [Regex]::Escape("^[$( $Block )]"))
    {
        Write-Error "Block [$( $Block )] not found in config content"
        $configContent
        return
    }
    $inBlock = $false
    $new = ""
    $ok = $false
    foreach ($Line in $configContent -split "`n")
    {
        if ($Line -match "^\[$( $Block )\]")
        {
            $inBlock = $true
        }
        elseif ($Line -match "^\[.*\]")
        {
            $inBlock = $false
        }
        if ($inBlock -and ($line -match "^([#, ])*$key = "))
        {
            $new = $new + "  $key = $value`n"
            $ok = $true
            $inBlock = $false
        }
        else
        {
            $new = $new + $line + "`n"
        }
    }
    if (-not$ok)
    {
        $e = @()
        $e += ": Key '$( $Key )' not found in config section [$( $Block )]."
        $e += ": Please add manually '$( $Key ) = `"$( $Value )`"'"
        Write-Error ($e -join "`n")
        return
    }
    if ( $PSCmdlet.ShouldProcess($ConfigContent))
    {
        Write-Debug $new
    }
    $new
    return
}

function Add-Netcard
{
    [OutputType([Object[]])]
    param (
        [Parameter(Mandatory)]
        [Object[]]$ConfigContent,
        [Parameter(Mandatory)]
        [CimInstance[]]$Interface,
        [Parameter(Mandatory)]
        [ValidateSet('net_lan', 'net_wan')]
        [String]$InterfaceType
    )
    if ($Interface.Length -gt 1)
    {
        Write-Information ""
        Write-Information "-----------------------::CAUTION::-----------------------"
        Write-Information ": You have more than one connected $( $InterfaceType ) card."
        Write-Information ": Just the first one will be activated for the monitoring."
        Write-Information ": Review the configuration file and adjust to your needs manually once the installation has finished."
        Write-Information ""
    }
    $InterfaceAlias = $Interface[0].InterfaceAlias
    $linkSpeed = ((Get-Netadapter|Where-Object Name -eq $InterfaceAlias)[0].LinkSpeed) -replace " Gbps", "000" -replace " Mbps", ""
    $linkSpeed = [math]::floor($linkSpeed);
    if (Test-TomlKeyExist -ConfigContent $ConfigContent -Block "monitoring" -Key $InterfaceType)
    {
        Write-Information "* Monitoring for $InterfaceType '$InterfaceAlias' already activated. Skipping."
        $ConfigContent
        return
    }
    try
    {
        $ConfigContent = Set-TomlVar -ConfigContent $ConfigContent -Block "monitoring" -Key $InterfaceType -Value "['$InterfaceAlias', '$linkSpeed']"
        Write-Information "* Monitoring for $InterfaceType '$InterfaceAlias' activated."
    }
    catch
    {
        Write-Information ": Monitoring for $InterfaceType '$InterfaceAlias' NOT activated."
        Write-Information $_
    }
    $ConfigContent
}

function Select-EnabledNetCard
{
    [OutputType([Object[]])]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        [object[]]$NetAdapters
    )
    process
    {
        $filtered = @()
        foreach ($NetAdapter in $NetAdapters)
        {
            try
            {
                if ("Up" -eq (Get-NetAdapter -Name $NetAdapter.InterfaceAlias).Status)
                {
                    $filtered += $NetAdapter
                }
            }
            catch
            {
                Write-Information ": Failed to get status of $( $NetAdapter.InterfaceAlias ). Net Adapter ignored."
            }

        }
        $filtered
        return
    }
}

function Enable-Network-Monitoring
{
    [OutputType([Object[]])]
    param (
        [Parameter(Mandatory)]
        [Object[]]$ConfigContent
    )
    if ($ConfigContent -match "^\s*net_[lw]an")
    {
        Write-Information "* Network Monitoring already enabled."
        $ConfigContent
        return
    }
    try
    {
        $netLan = (Get-NetIPAddress|Where-Object IPAddress -Match "^(10|192.168|172.16)"|Select-EnabledNetCard)
        $netWan = (Get-NetIPAddress|Where-Object AddressFamily -eq "IPv4"|Where-Object IPAddress -NotMatch "^(10|192.168|172.16|127.|169.254.)"|Select-EnabledNetCard)
    }
    catch
    {
        Write-Information ": Getting list of Network adapters with 'Get-NetIPAddress' failed. Notwork monitoring not activated."
        $ConfigContent
        return
    }

    if (-Not$netLan -and -Not$netWan)
    {
        Write-Information "* No Lan cards detected. Check manually with 'Get-NetAdapter'"
        $ConfigContent
        return
    }
    if ($netLan)
    {
        $ConfigContent = Add-Netcard -ConfigContent $ConfigContent -Interface $netLan -InterfaceType 'net_lan'
    }
    if ($netWan)
    {
        $ConfigContent = Add-Netcard -ConfigContent $ConfigContent -Interface $netWan -InterfaceType 'net_wan'
    }
    $ConfigContent
}

function Get-HostUUID
{
    try
    {
        (Get-CimInstance -Class Win32_ComputerSystemProduct).UUID
        return
    }
    catch
    {
        Write-Information ": Reading system UUID with 'Get-CimInstance -Class Win32_ComputerSystemProduct' failed."
        Write-Information ": Falling back to a md5 hash of the computer name."
        $hash = [System.Security.Cryptography.HashAlgorithm]::Create("md5").ComputeHash(
                [System.Text.Encoding]::UTF8.GetBytes($( $env:computername )))
        [System.BitConverter]::ToString($hash).Replace("-", "")
        return
    }
}

# Set the start type of the service
function Optimize-ServiceStartup
{
    param()
    #@formatter:off
    & sc.exe config rport start= delayed-auto
    & sc.exe failure rport reset= 0 actions= restart/5000
    #@formatter:on
}

function Invoke-Download
{
    Param(
        [Parameter()]
        [string]$gt = "0",
        [string]$pkgUrl
    )
    $Headers = @{ }
    if ($pkgUrl)
    {
        # Download from a custom URL given by global switch
        if ($pkgUrl -match ("^http.*windows_x86_64.zip"))
        {
            $downloadFile = "C:\Windows\temp\rport_Windows_x86_64.zip"
        }
        elseif ($pkgUrl -match ("^http.*windows_x86_64.msi"))
        {
            $downloadFile = "C:\Windows\temp\rport_Windows_x86_64.msi"
        }
        else
        {
            Write-Error "PkgUrl $( $pkgUrl ) is not a valid rport download url."
        }
        $url = $pkgUrl
        if ($env:RPORT_INSTALLER_DL_USERNAME -and $env:RPORT_INSTALLER_DL_PASSWORD)
        {
            $pair = "$( $env:RPORT_INSTALLER_DL_USERNAME ):$( $env:RPORT_INSTALLER_DL_PASSWORD )"
            $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
            $basicAuthValue = "Basic $encodedCreds"
            $Headers = @{
                Authorization = $basicAuthValue
            }
            Write-Information "* Downloading using HTTP basic auth"
        }
    }
    else
    {
        $downloadFile = "C:\Windows\temp\rport_$( $release )_Windows_x86_64.msi"
        $url = "https://downloads.openrport.io/rport/$( $release )/latest.php?filter=Windows_x86_64.msi&gt=$( $gt )"
    }

    if (Test-Path $downloadFile -PathType leaf)
    {
        Remove-Item $downloadFile -Force
    }
    Write-Information "* Downloading  $( $url )."
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $downloadFile -Headers $Headers
    return $downloadFile
}

# Create an uninstaller script for rport
function New-Uninstaller
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Set-Content -Path "$( $installDir )\uninstall.bat" -Value '
ECHO off
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
echo RPort removed
ping -n 2 127.0.0.1 > null
'
    Write-Output "* Uninstaller created in $( $installDir )\uninstall.bat."
}

function New-PSScriptFile
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Path,
        [Parameter(Mandatory = $true)]
        [string] $ScriptBlock
    )
    $ScriptBlock.Split("`n") | ForEach-Object {
        if ($_)
        {
            $_.Trim() | Out-File -FilePath $Path -Append
        }
    }
    $null = $Path
}

function Get-MSIVersionInfo
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $path
    )
    if (!(Test-Path $path.FullName))
    {
        throw "File '{0}' does not exist" -f $path.FullName
    }
    try
    {
        $WindowsInstaller = New-Object -com WindowsInstaller.Installer
        $Database = $WindowsInstaller.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $Null, $WindowsInstaller, @($path.FullName, 0))
        $Query = "SELECT Value FROM Property WHERE Property = 'ProductVersion'"
        $View = $database.GetType().InvokeMember("OpenView", "InvokeMethod", $Null, $Database, ($Query))
        $View.GetType().InvokeMember("Execute", "InvokeMethod", $Null, $View, $Null) | Out-Null
        $Record = $View.GetType().InvokeMember("Fetch", "InvokeMethod", $Null, $View, $Null)
        $Version = $Record.GetType().InvokeMember("StringData", "GetProperty", $Null, $Record, 1)
        return $Version
    }
    catch
    {
        throw "Failed to get MSI file version: {0}." -f $_
    }
}