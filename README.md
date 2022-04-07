
[![License](https://img.shields.io/github/license/cloudradar-monitoring/rport-pairing?style=for-the-badge)](https://github.com/cloudradar-monitoring/rport-pairing/blob/main/LICENSE)
[![Go Tests](https://img.shields.io/github/workflow/status/cloudradar-monitoring/rport-pairing/Go%20Test?style=for-the-badge&label=Go%20Tests&logo=Go)](https://github.com/cloudradar-monitoring/rport-pairing/actions/workflows/functional_test_linux.yml)
[![Linux Tests](https://img.shields.io/github/workflow/status/cloudradar-monitoring/rport-pairing/Functional%20Test%20Linux?style=for-the-badge&label=Linux%20Tests&logo=Linux)](https://github.com/cloudradar-monitoring/rport-pairing/actions/workflows/functional_test_linux.yml)
[![Windows Tests](https://img.shields.io/github/workflow/status/cloudradar-monitoring/rport-pairing/Functional%20Test%20Windows?style=for-the-badge&label=Windows%20Tests&logo=Windows)](https://github.com/cloudradar-monitoring/rport-pairing/actions/workflows/functional_test_windows.yml)

A service to install and connect rport clients easily.

> 📣 This repository holds the sources used to run the public pairing service on https://pairing.rport.io.

## 👫 Use the pairing service
Below you will get detailed information how the pairing works. The explained requests are executed by the RPort user interface when you click on the "Install Client" button.
### Deposit the details of your RPort server
A pairing code is created by submitting data via HTTP post requests. For example
```bash
curl --location --request POST 'http://127.0.0.1:9978' \
--form 'connect_url="http://myrport-server.example.com:8080"' \
--form 'client_id="asdfsd"' \
--form 'password="sdfs"' \
--form 'fingerprint="2a:c1:71:09:80:ba:7c:10:05:e5:2c:99:6d:15:56:24"'
```

Links to the installation snippets for Windows and Linux are returned. The deposited data is stored only in the memory of the running process using [go-cache](https://github.com/patrickmn/go-cache). 

Sample response:
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
### Retrieve an installer - do the pairing
An HTTP get request to the pairing service `http://127.0.0.1:9978/9L6fHH` returns an installer script (bash/dash or PowerShell) containing all credentials needed to connect the client.
Windows and Linux are differentiated by the user agent header.
This enables you to install the rport client and directly connect it to your server with just a few lines on a terminal, using copy and paste.

**On Windows:**
```powershell
iwr https://pairing.example.com/9L6fHH -outfile rport-installer.ps1
./rport-installer.ps1
```

**On Linux:**
```bash
curl https://pairing.example.com/9L6fHH -o rport-installer.sh
sudo sh rport-installer.sh
```

### Update clients
The paring service also delivers an update script for Windows and Linux to update clients to the latest version and perform all changes to the config needed to activate the latest features.
The update scripts don't contain credentials or server specific data. Therefor no prior data deposit is needed. Just download and execute.

**On Windows:**
```powershell
iwr https://pairing.example.com/update -outfile rport-update.ps1
./rport-update.ps1
```

**On Linux:**
```bash
curl https://pairing.example.com/update -o rport-update.sh
sudo sh rport-update.sh
```

## 🚚 Install and run a pairing service
Because the service does not store any data, there is nothing to stop you using the public and free service on https://pairing.rport.io.
This public service is also the predefined default on all RPort server installations.

To run the service on your server proceed as follows.

````bash
VERSION="0.0.2"
cd /tmp
curl -LO https://github.com/cloudradar-monitoring/rport-pairing/releases/download/${VERSION}/rport-pairing_${VERSION}_Linux_x86_64.tar.gz
tar xf rport-pairing_${VERSION}_Linux_x86_64.tar.gz
mv rport-pairing /usr/local/bin/
mv rport-pairing.conf.example /etc/rport/rport-pairing.conf
mv rport-pairing.service /etc/systemd/system/
rm rport-pairing_${VERSION}_Linux_x86_64.tar.gz
````

Edit the config `/etc/rport/rport-pairing.conf` and start the service with `systemctl start rport-pairing`.

It's strongly recommended running the pairing service behind a reverse proxy with encryption. 
Likely you want to run the RPort server and the pairing service on the same host with name based virtual hosts (SNI).

Below you will find an example for the [caddy server](https://caddyserver.com/).
```
:9999 {
  reverse_proxy * 127.0.0.1:9978
  log {
	output file /var/log/rport/rport-pairing.log
  }
}
```

## ✏️ Contribute
### Test before pushing
Before you push changes to the Linux shell or Windows Powershell scripts, test them locally.
To test just the generated scripts no deposit of data is needed. 
You can use a fixed test pairing code like `0000000` that writes static data to the scripts as specified in the [`rport-pairing.conf`](./rport-pairing.conf.example) 
#### Bash-Linux installer
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

#### PowerShell-Windows installer
```powershell
iwr "http://localhost:9090/0000000" -oufile rport-install.ps1
Import-Module -Name PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path rport-install.ps1
```

If you haven't installed [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) open a PowerShell and install it.
```powershell
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
```


