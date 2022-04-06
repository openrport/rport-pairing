$ErrorActionPreference = "Stop"
# Start the pairing service
[IO.File]::WriteAllLines("start_srv.bat", "go run cmd/rport-pairing.go  -c ./rport-pairing.conf.example")
Start-Process -NoNewWindow start_srv.bat -RedirectStandardError start_srv.err.txt -RedirectStandardOutput start_srv.out.txt
for ($i = 1; $i -le 10; $i++) {
    if ((Test-NetConnection -Port 9090 -ComputerName "127.0.0.1").TcpTestSucceeded) {
        break
    }
    sleep 1
    "Waiting for server to come up"
}