package deposit

import "time"

type Deposit struct {
	Code        string `mapstructure:"code"`
	ConnectUrl  string `validate:"required,url" json:"connect_url" mapstructure:"connect_url"`
	Fingerprint string `validate:"required,len=47" json:"fingerprint" mapstructure:"fingerprint"`
	ClientId    string `validate:"required" json:"client_id" mapstructure:"client_id"`
	Password    string `validate:"required" json:"password" mapstructure:"password"`
}

type Response struct {
	PairingCode string    `json:"pairing_code"`
	Expires     time.Time `json:"expires"`
	Installers  struct {
		Linux   string `json:"linux"`
		Windows string `json:"windows"`
	} `json:"installers"`
}
