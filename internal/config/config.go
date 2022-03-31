package config

import (
	"fmt"
	"github.com/cloudradar-monitoring/rport-pairing/deposit"
	"github.com/spf13/viper"
)

type Config struct {
	Server struct {
		Address string
		Url     string
	}
	StaticDeposit deposit.Deposit
	DummyCode     string
}

func New(confFile string) *Config {
	viper.SetConfigName(confFile)
	viper.SetConfigType("toml")
	viper.AddConfigPath(".")
	err := viper.ReadInConfig()
	if err != nil {
		panic(fmt.Errorf("Fatal error config file: %w \n", err))
	}
	config := Config{}
	viper.SetDefault("server.address", "127.0.0.1:8080")
	config.Server.Address = viper.GetString("server.address")
	viper.SetDefault("server.url", "https://pairing.exmaple.com")
	config.Server.Url = viper.GetString("server.url")
	config.StaticDeposit.ConnectUrl = viper.GetString("static-deposit.connect_url")
	config.StaticDeposit.Fingerprint = viper.GetString("static-deposit.fingerprint")
	config.StaticDeposit.ClientId = viper.GetString("static-deposit.client_id")
	config.StaticDeposit.Password = viper.GetString("static-deposit.password")
	config.DummyCode = viper.GetString("static-deposit.code")
	return &config
}
