$ErrorActionPreference = "Stop"

# Start the pairing service
go run cmd/rport-pairing.go  -c ./rport-pairing.conf.example >app.log
for ($i = 1; $i -le 10; $i++) {
    if ((Test-NetConnection -Port 9090 -ComputerName "127.0.0.1").TcpTestSucceeded) {
        break
    }
    sleep 1
    "Waiting for server to come up"
}