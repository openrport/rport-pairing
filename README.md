
[![License](https://img.shields.io/github/license/openrport/rport-pairing?style=for-the-badge)](https://github.com/openrport/rport-pairing/blob/main/LICENSE)
[![Go Tests](https://img.shields.io/github/actions/workflow/status/openrport/rport-pairing/go_test.yml?branch=main&style=for-the-badge&label=Go%20Tests&logo=Go)](https://github.com/openrport/rport-pairing/actions/workflows/functional_test_linux.yml)
[![Linux Tests](https://img.shields.io/github/actions/workflow/status/openrport/rport-pairing/functional_test_linux.yml?branch=main&style=for-the-badge&label=Linux%20Tests&logo=Linux)](https://github.com/openrport/rport-pairing/actions/workflows/functional_test_linux.yml)
[![Windows Tests](https://img.shields.io/github/actions/workflow/status/openrport/rport-pairing/functional_test_windows.yml?branch=main&style=for-the-badge&label=Windows%20Tests&logo=Windows)](https://github.com/openrport/rport-pairing/actions/workflows/functional_test_windows.yml)

> This repository is a fork from the original cloudradar-monitoring paring service for rport in an effort to continue an opensource version.

A service to install and connect rport clients easily.

> 📣 This repository holds the sources used to run the public pairing service on https://pairing.rport.io.

## 👫 Use the pairing service
Below you will get detailed information how the pairing works. The explained requests are executed by the RPort user interface when you click on the "Install Client" button.
### Deposit the details of your RPort server
A pairing code is created by submitting data via HTTP post requests. For example:
```bash
curl --location --request POST 'http://127.0.0.1:9978' \
--form 'connect_url="http://myrport-server.example.com:8080"' \
--form 'client_id="asdfsd"' \
--form 'password="sdfs"' \
--form 'fingerprint="2a:c1:71:09:80:ba:7c:10:05:e5:2c:99:6d:15:56:24"'
```
Using a json-request is supported too:
````bash
curl 'http://127.0.0.1:9978' -X POST \
 -H 'Content-Type: application/json;charset=utf-8' \
 --data-raw '{
  "connect_url": "http://myrport-server.example.com:8080",
  "fingerprint": "2a:c1:71:09:80:ba:7c:10:05:e5:2c:99:6d:15:56:24",
  "client_id": "asdfsd",
  "password": "sdfs"
}'
````

Links to the installation scripts for Windows and Linux are returned. The deposited data is stored only in the memory of the running process using [go-cache](https://github.com/patrickmn/go-cache). 

Sample response for the above requests:
```json
{
    "pairing_code": "9L6fHH",
    "expires": "2022-04-08T09:39:04.282519Z",
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
cd /tmp
curl -LO https://github.com/openrport/rport-pairing/releases/latest/download/rport-pairing_Linux_$(uname -m).tar.gz
tar xf rport-pairing*Linux*.tar.gz
mv rport-pairing /usr/local/bin/
mv rport-pairing.conf.example /etc/rport/rport-pairing.conf
mv rport-pairing.service /etc/systemd/system/
rm rport-pairing*Linux*.tar.gz
````

Edit the config `/etc/rport/rport-pairing.conf` and start the service with `systemctl start rport-pairing` and enable the auto-start on boot with `systemctl enable rport-pairing`.

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
```
Shellcheck must terminate with exit code 0.

[Shellcheck](https://github.com/koalaman/shellcheck#user-content-installing) can be installed on MacOS or Linux using common package managers.

#### PowerShell-Windows installer
```powershell
iwr "http://localhost:9090/0000000" -OutFile rport-install.ps1
Import-Module -Name PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path rport-install.ps1
iwr "http://localhost:9090/update" -OutFile rport-update.ps1
Import-Module -Name PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path rport-update.ps1
```

If you haven't installed [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) open a PowerShell and install it.
```powershell
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
```

### Test your local version on remote systems
#### On Linux
Run the pairing service on your dev machine.
```bash
$ go run ./cmd/rport-pairing.go -c rport-pairing.conf.example
2022/09/08 17:44:30 Server started on  127.0.0.1:9090
```

Use SSH port forwarding to make the web server available on a remote system. For example:
```bash
$ ssh 10.131.216.191 -l root -R 9090:127.0.0.1:9090
```
Now you can do the pairing or an update using:
```bash
curl http://localhost:9090/0000000 -o rport-installer.sh
sudo sh rport-installer.sh
```
