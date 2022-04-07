#!/usr/bin/env bash
set -e
trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG
trap 'echo "exit $? due to $previous_command"' EXIT

## Start the pairing service
go run cmd/rport-pairing.go  -c ./rport-pairing.conf.example >app.log 2>&1 &
for C in $(seq 1 10);do
  ncat -w1 -z 127.0.0.1 9090 && break
  echo "${C}: Waiting for server to come up"
  sleep 1
done
pgrep -f "port-pairing -c ./rport-pairing.conf.example"