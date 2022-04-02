package config

import (
	"fmt"
	"github.com/cloudradar-monitoring/rport-pairing/deposit"
	"github.com/spf13/viper"
	"log"
)

type Config struct {
	Server struct {
		Address string `mapstructure:"address"`
		Url     string `mapstructure:"url"`
	} `mapstructure:"server"`
	StaticDeposit deposit.Deposit `mapstructure:"static-deposit"`
}

func New(confFile string) *Config {
	viper.SetConfigName(confFile)
	viper.SetConfigType("toml")
	viper.AddConfigPath("/etc/rport/")
	viper.AddConfigPath("$HOME/.rport")
	viper.AddConfigPath(".")
	err := viper.ReadInConfig()
	if err != nil {
		panic(fmt.Errorf("Fatal error: %w \n", err))
	}
	viper.SetDefault("server.address", "127.0.0.1:8080")
	viper.SetDefault("server.url", "https://pairing.exmaple.com")
	var config Config
	err = viper.Unmarshal(&config)
	if err != nil {
		log.Fatalf("unable to decode into struct, %v", err)
	}
	//config := Config{}
	//config.Server.Address = viper.GetString("server.address")
	//config.Server.Url = viper.GetString("server.url")
	//config.StaticDeposit.ConnectUrl = viper.GetString("static-deposit.connect_url")
	//config.StaticDeposit.Fingerprint = viper.GetString("static-deposit.fingerprint")
	//config.StaticDeposit.ClientId = viper.GetString("static-deposit.client_id")
	//config.StaticDeposit.Password = viper.GetString("static-deposit.password")
	//config.DummyCode = viper.GetString("static-deposit.code")
	return &config
}
