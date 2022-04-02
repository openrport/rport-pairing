package retrieve

import (
	"fmt"
	"github.com/cloudradar-monitoring/rport-pairing/deposit"
	"net/http"
)

type UpdateHandler struct {
	StaticDeposit deposit.Deposit
}

// Handle the request for a client update.
// No client data is needed
func (rh *UpdateHandler) ServeHTTP(rw http.ResponseWriter, r *http.Request) {
	renderUpdate(rw, clientOs(r))
}

func renderUpdate(rw http.ResponseWriter, os string) {
	switch os {
	case "windows":
		writeFile(rw, "templates/header.txt")
		writeFile(rw, "templates/windows/functions.ps1")
		writeFile(rw, "templates/windows/update.ps1")
	default:
		fmt.Fprintln(rw, "#!/bin/sh -e")
		writeFile(rw, "templates/header.txt")
		writeFile(rw, "templates/linux/functions.sh")
		writeFile(rw, "templates/linux/update.sh")
	}
}
