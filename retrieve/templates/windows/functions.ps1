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
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $DestinationPath)
    }
}

function Add-ToConfig
{
    <#
    .SYNOPSIS
        Add a line to a block of a the rport toml configuration.
    #>
    Param(
        [parameter(Mandatory = $true)]
        [String] $Block,
        [parameter(Mandatory = $true)]
        [String] $Line
    )
    $configContent = Get-Content $configFile -Raw
    if ($configContent -NotMatch "\[$block\]")
    {
        # Append the block if missing
        $configContent = "$configContent`n`n[$block]"
    }
    if ($configContent -Match [System.Text.RegularExpressions.Regex]::Escape($Line))
    {
        Write-Output "$Line already present in configuration."
        return
    }
    Write-Output "* Adding `"$Line`" to [$Block]"
    $configContent = $configContent -replace "\[$Block\]", "$&`n  $Line"
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [IO.File]::WriteAllLines($configFile, $configContent, $Utf8NoBomEncoding)
}

function Find-Interpreter
{
    <#
    .SYNOPSIS
        Find common script interpreters installed on the system
    #>
    $interpreters = @{ }
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

function Push-InterpretersToConfig
{
    <#
    .SYNOPSIS
        Push interpreters to the rport.conf
    #>
    if (-Not([System.Version]$targetVersion -ge [System.Version]"0.5.12"))
    {
        Write-Output "* RPort version $targetVersion does not support Interpreter Aliases"
        return
    }
    Write-Output "* Looking for script interpreters."
    $interpreters = Find-Interpreter
    Write-Output "* $( $interpreters.count ) script interpreters found."
    $interpreters.keys|ForEach-Object {
        $key = $_
        $value = $interpreters[$_]
        Add-ToConfig -Block "interpreter-aliases" -Line "$key = '$value'"
    }
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
        $tacoUpdateUrl = "https://downloads.rport.io/tacoscript/$( $release )/?arch=Windows_x86_64&gt=$tacoVersion"
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
    $url = "https://download.rport.io/tacoscript/$( $release )/?arch=Windows_x86_64"
    $file = $temp + "\tacoscript.zip"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
    Write-Output "* Tacoscript dowloaded to $( $file )"
    New-Item -ItemType Directory -Force -Path "$( $tacoDir )\bin"|Out-Null
    Expand-Zip -Path $file -DestinationPath $tacoDir
    Move-Item "$( $tacoDir )\tacoscript.exe" "$( $tacoDir )\bin"
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

function Set-TomlVar
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [String]$FileContent,
        [Parameter(Mandatory)]
        [String]$Block,
        [Parameter(Mandatory)]
        [String]$Key,
        [Parameter(Mandatory)]
        [String]$Value
    )
    if (-not $FileContent.Contains("[$Block]"))
    {
        Write-Error "Block [$( $Block )] not found in toml content"
        return
    }
    $inBlock = $false
    $new = ""
    $ok = $false
    foreach ($Line in $FileContent -split "`n")
    {
        if ($Line -match "^\[$( $Block )\]")
        {
            $inBlock = $true
        }
        elseif ($Line -match "\[.*\]")
        {
            $inBlock = $false
        }
        if ($inBlock -and ($line -match "^([#, ])*$key = "))
        {
            $new = $new + "  $key = $value`n"
            $ok = $true
        }
        else
        {
            $new = $new + $line + "`n"
        }
    }
    if(-not $ok)
    {
        Write-Error "Key $key not found in toml content"
        return
    }
    if($PSCmdlet.ShouldProcess($FileContent)){
        $new
    }
    $new
    return
}

function Add-Netcard
{
    param (
        [Parameter(Mandatory)]
        [CimInstance[]]$Interface,
        [Parameter(Mandatory)]
        [ValidateSet('net_lan', 'net_wan')]
        [String[]]$Type
    )
    $InterfaceAlias = $Interface[0].InterfaceAlias
    $linkSpeed = ((Get-Netadapter|Where-Object Name -eq $InterfaceAlias)[0].LinkSpeed) -replace " Gbps", "000" -replace " Mbps", ""
    $linkSpeed = [math]::floor($linkSpeed);
    $configContent = Get-Content $configFile -Raw
    if ($configContent -match "[^#]\s*$Type = \[")
    {
        Write-Output "* Monitoring for $Type '$InterfaceAlias' already activated. Skipping."
        return
    }
    if ($configContent -match "#+\s*$( $Type ) =")
    {
        # Try to replace the commented example
        $configContent = $configContent -replace "#+\s*$( $Type ) = .*", "$( $Type ) = ['$InterfaceAlias', '$linkSpeed']"
    }
    else
    {
        $configContent = $configContent -replace '\[monitoring\]', "$&`n  $( $Type ) = ['$InterfaceAlias', '$linkSpeed']"
    }
    Write-Output "* Monitoring for $Type '$InterfaceAlias' activated."
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [IO.File]::WriteAllLines($configFile, $configContent, $Utf8NoBomEncoding)
}

function Enable-Network-Monitoring
{
    if (-Not([System.Version]$targetVersion -ge [System.Version]"0.5.8"))
    {
        Write-Output "* RPort version $targetVersion does not support Lan/Wan Monitoring"
        return
    }
    if ((get-content $configFile) -match "^\s*net_[lw]an")
    {
        Write-Output "* Network Monitoring already enabled"
        return
    }
    $netLan = (Get-NetIPAddress|Where-Object IPAddress -Match "^(10|192.168|172.16)")
    $netWan = (Get-NetIPAddress|Where-Object AddressFamily -eq "IPv4"|Where-Object IPAddress -NotMatch "^(10|192.168|172.16|127.)")
    if (-Not$netLan -and -Not$netWan)
    {
        Write-Output "* No Lan cards detected. Check manually with 'Get-NetAdapter'"
        return
    }
    if ($netLan)
    {
        Add-Netcard $netLan 'net_lan'
    }
    if ($netWan)
    {
        Add-Netcard $netWan 'net_wan'
    }
}