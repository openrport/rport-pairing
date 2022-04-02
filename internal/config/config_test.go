package config_test

import (
	"github.com/cloudradar-monitoring/rport-pairing/internal/config"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestConfig(t *testing.T) {
	config := config.New("../../rport-pairing.conf.example")
	assert.Equal(t, "127.0.0.1:9090", config.Server.Address, "error getting [server] address")
	assert.Equal(t, "https://pairing.example.local", config.Server.Url)
	assert.Equal(t, "http://rport.example.com:8080", config.StaticDeposit.ConnectUrl, "error getting [static-deposit] connect_url")
	assert.Equal(t, "2a:c4:79:04:80:ba:7c:60:05:e5:2c:49:6d:74:56:24", config.StaticDeposit.Fingerprint, "error getting [static-deposit] fingerprint")
	assert.Equal(t, "client1", config.StaticDeposit.ClientId, "error getting [static-deposit] client_id")
	assert.Equal(t, "foobaz", config.StaticDeposit.Password, "error getting [static-deposit] password")
}
