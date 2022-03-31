package config_test

import (
	"github.com/cloudradar-monitoring/rport-pairing/internal/config"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestConfig(t *testing.T) {
	config := config.New("../../rport-pairing.conf.example")
	assert.Contains(t, config.Server.Address, "127.0.0.1:9978")
	assert.Contains(t, config.Server.Url, "example.com")
	assert.Contains(t, config.StaticDeposit.ConnectUrl, "rport.example.com")
}
