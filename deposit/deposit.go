package deposit

import (
	"strings"
	"time"
)

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

func rplForBash(in string) (out string) {
	rpl := map[string]string{
		"\"": "\\\"",
		"$":  "\\$",
		"\\": "\\\\",
	}
	for s, r := range rpl {
		in = strings.ReplaceAll(in, s, r)
	}
	return in
}
func SanitizeForBash(in Deposit) (out Deposit) {
	return Deposit{
		Code:        rplForBash(in.Code),
		ConnectUrl:  rplForBash(in.ConnectUrl),
		Fingerprint: rplForBash(in.Fingerprint),
		ClientId:    rplForBash(in.ClientId),
		Password:    rplForBash(in.Password),
	}
}

func rplForPowerShell(in string) (out string) {
	rpl := map[string]string{
		"\"": "`\"",
		"$":  "`$",
		"`":  "``",
	}
	for s, r := range rpl {
		in = strings.ReplaceAll(in, s, r)
	}
	return in
}
func SanitizeForPowerShell(in Deposit) (out Deposit) {
	return Deposit{
		Code:        rplForPowerShell(in.Code),
		ConnectUrl:  rplForPowerShell(in.ConnectUrl),
		Fingerprint: rplForPowerShell(in.Fingerprint),
		ClientId:    rplForPowerShell(in.ClientId),
		Password:    rplForPowerShell(in.Password),
	}
}
