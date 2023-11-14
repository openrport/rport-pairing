$ErrorActionPreference = "Stop"
mkdir C:\rport
Set-Location C:\rport
Invoke-WebRequest "https://download.openrport.io/rportd/stable/?arch=Windows_x86_64" -OutFile rportd.zip
Expand-Archive rportd.zip .
./rportd --version

$config_file = "C:\rport\rportd.conf"
$config_content = '[server]
  address = "127.0.0.1:8080"
  key_seed = "5448e69530b4b97fb510f96ff1550500b093"
  #-> Fingerprint: 36:98:56:12:f3:dc:e5:8d:ac:96:48:23:b6:f0:42:15
  auth = "client1:foobaz"
  data_dir = "C:/rport"
[logging]
  log_file = "C:/rport/rportd.log"
  log_level = "debug"
'
[IO.File]::WriteAllLines($config_file, $config_content)
.\rportd.exe --service install --config "C:\rport\rportd.conf"
start-service rportd
Get-service rportd
(Test-NetConnection -Port 8080 -ComputerName "127.0.0.1").TcpTestSucceeded
Get-ChildItem C:\rport