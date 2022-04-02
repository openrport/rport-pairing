#!/usr/bin/env bash
set -e
#
# Do a very simple functional test
#
go run cmd/rport-pairing.go  -c ./rport-pairing.conf.example >app.log  2>&1 &
sleep 1

echo "Generating new pairing code"
curl -sf --location -o response.json \
--request POST 'http://127.0.0.1:9090' \
--form 'connect_url="http://myrport-server.example.com:8080"' \
--form 'client_id="my_test_client"' \
--form 'password="foobaz"' \
--form 'fingerprint="2a:c1:71:09:80:ba:7c:10:05:e5:2c:99:6d:15:56:24"'

jq < response.json
PAIRING_CODE=$(jq -r .pairing_code < response.json)
echo "Testing installer for Linux"
curl -fs "http://127.0.0.1:9090/${PAIRING_CODE}" 2>&1|grep -q 'END of templates/linux/install.sh'
echo "Testing installer for Windows"
curl -fs -H "User-Agent:PowerShell" "http://127.0.0.1:9090/${PAIRING_CODE}" 2>&1|grep -q 'END of templates/windows/install.ps1'
echo "Testing Update for Linux"
curl -fs "http://127.0.0.1:9090/update" 2>&1|grep -q 'END of templates/linux/update.sh'
echo "Testing Update for Windows"
curl -fs -H "User-Agent:PowerShell" "http://127.0.0.1:9090/update" 2>&1|grep -q 'END of templates/windows/update.ps1'
cat app.log
pkill -f "go run cmd/rport-pairing.go"||true