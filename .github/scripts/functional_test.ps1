$ErrorActionPreference = "Stop"
# Start the pairing service
[IO.File]::WriteAllLines("start_srv.bat", "go run cmd/rport-pairing.go  -c ./rport-pairing.conf.example")
dir
Start-Process -NoNewWindow start_srv.bat -RedirectStandardError start_srv.err.txt -RedirectStandardOutput start_srv.out.txt
Write-Output "Starting Pairing service in the background"
for ($i = 1; $i -le 30; $i++) {
    if ((Test-NetConnection -Port 9090 -ComputerName "127.0.0.1").TcpTestSucceeded)
    {
        Write-Output "Pairing sevice is running"
        break
    }
    "[$( $i )] .. Waiting for server to come up"
    sleep 2
}
dir
Get-Content start_srv.err.txt
Get-Content start_srv.out.txt
Write-Output "Generating new pairing code"
$Uri = 'http://127.0.0.1:9090'
$Form = @{
    connect_url = 'http://127.0.0.1:8080'
    client_id = 'client1'
    password = 'foobaz'
    fingerprint = '36:98:56:12:f3:dc:e5:8d:ac:96:48:23:b6:f0:42:15'
}
$Result = Invoke-RestMethod -Uri $Uri -Method Post -Form $Form
$Result|ConvertTo-Json
Invoke-Webrequest ($Uri + '/' + ($Result.pairing_code)) -outfile rport-installer.ps1

Write-Output "Running PS Script Analyzer"
Import-Module -Name PSScriptAnalyzer -force
Invoke-ScriptAnalyzer -Path rport-installer.ps1 -EnableExit -ReportSummary

# Execute the installer
Write-output "Executing the installer now"
./rport-installer.ps1 -x

# Verify the client has connected to the local rportd
Write-Output "Verifying client is connected to server"
Get-Content C:\rport\rportd.log|Select-String -Pattern "client-listener.*Open.*$( $env:ComputerName )"

# Execute the update script
Write-Output "Executing the update script now"
Invoke-Webrequest ($Uri + '/update') -outfile rport-update.ps1
Invoke-ScriptAnalyzer -Path rport-update.ps1 -ReportSummary -EnableExit
./rport-update.ps1 -t