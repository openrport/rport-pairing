package retrieve

import (
	"fmt"
	"github.com/cloudradar-monitoring/rport-pairing/deposit"
	"github.com/gorilla/mux"
	"github.com/patrickmn/go-cache"
	"net/http"
)

type InstallerHandler struct {
	StaticDeposit deposit.Deposit
	Cache         *cache.Cache
}

// Handle the request for previously pairing data aka client credentials identified by the pairing code.
// If pairing code exists, render an installer script with client credentials as variables dynamically inserted.
func (rh *InstallerHandler) ServeHTTP(rw http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	pairingCode := vars["pairingCode"]
	os := clientOs(r)
	var data deposit.Deposit
	if pairingCode == rh.StaticDeposit.Code {
		data = rh.StaticDeposit
	} else {
		val, found := rh.Cache.Get(pairingCode)
		if !found {
			rw.WriteHeader(http.StatusNotFound)
			fmt.Fprintf(rw, "#No pairing found by pairing code %s\n", pairingCode)
			return
		}
		data = val.(deposit.Deposit)
	}
	renderInstaller(rw, os, data)
}

func renderInstaller(rw http.ResponseWriter, os string, data interface{}) {
	switch os {
	case "windows":
		writeFile(rw, "templates/header.txt")
		renderTemplate(rw, "templates/windows/vars.ps1", data)
		writeFile(rw, "templates/windows/functions.ps1")
		writeFile(rw, "templates/windows/install.ps1")
	default:
		fmt.Fprintln(rw, "#!/bin/sh -e")
		writeFile(rw, "templates/header.txt")
		renderTemplate(rw, "templates/linux/vars.sh", data)
		writeFile(rw, "templates/linux/functions.sh")
		writeFile(rw, "templates/linux/install.sh")
	}
}
