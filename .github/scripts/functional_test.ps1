$ErrorActionPreference = "Stop"

Write-Output "Generating new pairing code"
$Uri = 'http://127.0.0.1:9978'
$Form = @{
    connect_url = 'http://127.0.0.2:8080'
    client_id = 'client1'
    email = 'john.doe@contoso.com'
    password = 'foobaz'
    fingerprint = '36:98:56:12:f3:dc:e5:8d:ac:96:48:23:b6:f0:42:15'
}
$Result = Invoke-RestMethod -Uri $Uri -Method Post -Form $Form
$Result|ConvertTo-Json
Invoke-Webrequest ($Uri+'/'+($Result.pairing_code)) -outfile rport-install.ps1
# Execute the installer
Write-output "Executing the install now"
./rport-install.ps1 -x

# Verify the client has connected to the local rportd
Write-Output "Verifying client is connected to server"
Get-Content C:\rport\rportd.log|Select-String -Pattern "client-listener.*Open.*$($env:ComputerName)"

# Execute the update script
Write-Output "Executing the update script now"
Invoke-Webrequest ($Uri+'/update') -outfile rport-update.ps1
./rport-update.ps1 -t