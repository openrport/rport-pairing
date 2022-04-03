#!/usr/bin/env bash
set -e
trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG
trap 'echo "exit $? due to $previous_command"' EXIT
#
# Do a functional test
#

echo "Generating new pairing code"
curl -sf --location -o response.json \
--request POST 'http://127.0.0.1:9090' \
--form 'connect_url="http://127.0.0.2:8080"' \
--form 'client_id="client1"' \
--form 'password="foobaz"' \
--form 'fingerprint="36:98:56:12:f3:dc:e5:8d:ac:96:48:23:b6:f0:42:15"'

# Check the response is valid Json
echo "Got pairing code and data"
jq < response.json

# Retrieve the Linux installer script from the deposited values above
PAIRING_CODE=$(jq -r .pairing_code < response.json)
echo "Testing installer for Linux"
curl -fs "http://127.0.0.1:9090/${PAIRING_CODE}" -o rport-installer.sh 2>&1
grep -q 'END of templates/linux/install.sh' rport-installer.sh

# Check the shell script passes all shellchecks
echo "Running shellcheck for rport-installer.sh"
shellcheck rport-installer.sh

# Check by executing the help function
sudo sh rport-installer.sh -h|grep "Install with SELinux enabled"

# Execute the installer
echo "Executing the install now"
sudo sh rport-installer.sh -x -s

# Verify the client has connected to the local rportd
echo "Verifying client is connected to server"
grep "client-listener.*Open.*$(hostname)" /tmp/rportd.log