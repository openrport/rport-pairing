package retrieve

import (
	"embed"
	"fmt"
	"github.com/cloudradar-monitoring/rport-pairing/deposit"
	"github.com/gorilla/mux"
	"github.com/patrickmn/go-cache"
	"log"
	"net/http"
	"regexp"
	"strings"
	"text/template"
)

type Handler struct {
	DummyCode     string
	StaticDeposit deposit.Deposit
	Cache         *cache.Cache
}

//go:embed templates
var templates embed.FS

// Handle the request for previously pairing data aka client credentials identified by the pairing code.
// If pairing code exists, render an installer script with client credentials as variables dynamically inserted.
func (rh *Handler) ServeHTTP(rw http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	pairingCode := vars["pairingCode"]
	windows := regexp.MustCompile(`PowerShell`)
	var os string
	if windows.MatchString(r.UserAgent()) {
		os = "windows"
	} else {
		os = "linux"
	}
	if r.URL.Path == "/update" {
		renderUpdate(rw, os)
		return
	}
	var data deposit.Deposit
	if pairingCode == rh.DummyCode {
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

func renderInstaller(rw http.ResponseWriter, os string, data interface{}) {
	switch os {
	case "windows":
		writeFile(rw, "templates/header.txt")
		render(rw, "templates/windows/vars.ps1", data)
		writeFile(rw, "templates/windows/functions.ps1")
		writeFile(rw, "templates/windows/install.ps1")
	default:
		fmt.Fprintln(rw, "#!/bin/sh -e")
		writeFile(rw, "templates/header.txt")
		render(rw, "templates/linux/vars.sh", data)
		writeFile(rw, "templates/linux/functions.sh")
		writeFile(rw, "templates/linux/install.sh")
	}
}

// Render a template and write it to the response writer
func render(rw http.ResponseWriter, tplFile string, data interface{}) {
	fmt.Fprintf(rw, "## BEGINNING of rendered templarte %s \n", tplFile)
	tpl, err := template.ParseFS(templates, tplFile)
	if err != nil {
		fmt.Fprintf(rw, "# parsing template file %s failed:%s", tplFile, err)
		log.Printf("parsing template file %s failed:%s", tplFile, err)
		return
	}
	if err := tpl.Execute(rw, data); err != nil {
		fmt.Fprintf(rw, "# executing template file '%s' failed: %s", tplFile, err)
		log.Printf("executing template file '%s' failed: %s", tplFile, err)
	}
	fmt.Fprintf(rw, "\n## END of rendered template %s \n\n", tplFile)
}

// Read a file and write it to the response writer followed by a new line
func writeFile(rw http.ResponseWriter, name string) {
	if fr, err := templates.ReadFile(name); err != nil {
		log.Printf("error reading file %s: %s", name, err)
	} else {
		fmt.Fprintf(rw, "\n# BEGINNING of %s %s|\n\n", name, strings.Repeat("-", 102-len(name)))
		if _, err := rw.Write(fr); err != nil {
			log.Println("error writing http response: ", err)
		}
		fmt.Fprintf(rw, "\n# END of %s %s|\n\n", name, strings.Repeat("-", 111-len(name)))
	}
}
