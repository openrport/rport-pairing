package deposit

type Deposit struct {
	ConnectUrl  string `validate:"required,url" json:"connect_url"`
	Fingerprint string `validate:"required,len=47" json:"fingerprint"`
	ClientId    string `validate:"required" json:"client_id"`
	Password    string `validate:"required" json:"password"`
}

type Response struct {
	PairingCode string `json:"pairing_code"`
	Expires     struct {
		Timestamp int64  `json:"timestamp"`
		DateTime  string `json:"date_time"`
	} `json:"expires"`
	Installers struct {
		Linux   string `json:"linux"`
		Windows string `json:"windows"`
	} `json:"installers"`
}
