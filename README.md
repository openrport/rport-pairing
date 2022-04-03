# Rport-Pairing
[![GitHub issues](https://img.shields.io/github/issues/cloudradar-monitoring/rport-pairing.svg)](https://github.com/matoous/go-nanoid/issues)
[![License](https://img.shields.io/badge/license-MIT%20License-blue.svg)](https://github.com/cloudradar-monitoring/rport-pairing/blob/main/LICENSE)

A service to install and connect rport clients easily.

## Create an installer
Installers and pairing codes are created by HTTP post requests. For example
```bash
curl --location --request POST 'http://127.0.0.1:9978' \
--form 'connect_url="http://myrport-server.example.com:8080"' \
--form 'client_id="asdfsd"' \
--form 'password="sdfs"' \
--form 'fingerprint="2a:c1:71:09:80:ba:7c:10:05:e5:2c:99:6d:15:56:24"'
```

Installation snippets for Windows and Linux are returned.  Example:
```json
{
    "pairing_code": "9L6fHH",
    "expires": {
        "timestamp": 1607515247,
        "date_time": "2020-12-09T12:00:47+00:00"
    },
    "installers": {
        "linux": "curl -o rport-installer.sh https://pairing.rport.io/9L6fHH && sudo sh rport-installer.sh",
        "windows": "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12\n$url=\"https://pairing.rport.io/9L6fHH\"\nInvoke-WebRequest -Uri $url -OutFile \"rport-installer.bat\"\nexec rport-installer.bat"
    }
}
```

## Test before pushing
Before you push changes to the Linux shell or Windows Powershell scripts, test them locally.

### Bash
```bash
go run ./cmd/rport-pairing.go -c rport-pairing.conf.example &
sleep 2
curl http://localhost:9090/0000000 -o rport-install.sh
shellcheck rport-install.sh
curl http://localhost:9090/update -o rport-update.sh
shellcheck rport-update.sh
pkill -f "rport-pairing.* -c rport-pairing.conf.example"
```
Shellcheck must terminate with exit code 0.

[Shellcheck](https://github.com/koalaman/shellcheck#user-content-installing) can be installed on MacOS or Linux using common package managers.

### PowerShell
```bash
curl -H "User-Agent:PowerShell" http://localhost:9978/0000000 -o rport-install.ps1
pwsh -Command "Import-Module -Name PSScriptAnalyzer;Invoke-ScriptAnalyzer -Path rport-install.ps1"
```

If you haven't installed [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) open a PowerShell and install it.
```powershell
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
```


## Retrieve an installer - do the pairing
A HTTP get request to the pairing service `https://pairing.rport.io/9L6fHH` returns an installer snippet containing all credentials needed to connect the client.