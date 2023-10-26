#!/usr/bin/env bash
set -e
trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG
trap 'echo "exit $? due to $previous_command"' EXIT
#
# Run a local instance of the RPort server to test if the pairing scripts successfully connects to this server.
#
cd /tmp
curl -Ls "https://download.openrport.io/rportd/stable/latest.php?arch=x86_64" -o rportd.tar.gz
tar xvzf rportd.tar.gz rportd
mkdir /tmp/rport-data
cat<<EOF>rportd.conf
[server]
  address = "127.0.0.1:8080"
  key_seed = "5448e69530b4b97fb510f96ff1550500b093"
  #-> Fingerprint: 36:98:56:12:f3:dc:e5:8d:ac:96:48:23:b6:f0:42:15
  auth = "client1:foobaz"
  data_dir = "/tmp/rport-data"
[logging]
  log_file = "/tmp/rportd.log"
  log_level = "debug"
EOF

echo -n "RPortd "
./rportd -version
./rportd -c rportd.conf &
for C in $(seq 1 10);do
  ncat -w1 -z 127.0.0.1 8080 && break
  echo "${C}: Waiting for server to come up"
  sleep 1
done
echo -n "RPortd pid "
pidof rportd