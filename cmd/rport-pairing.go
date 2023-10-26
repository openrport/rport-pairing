package main

import (
	"flag"
	"fmt"
	"github.com/gorilla/mux"
	"github.com/openrport/rport-pairing/cors"
	"github.com/openrport/rport-pairing/deposit"
	"github.com/openrport/rport-pairing/internal/cache"
	"github.com/openrport/rport-pairing/internal/config"
	"github.com/openrport/rport-pairing/retrieve"
	"log"
	"net/http"
	"os"
)

// Version Placeholder var that gets filled on compile time with -ldflags="-X 'main.Version=N.N.N'"
var Version = "0.0.0-src"

func main() {
	v := false
	flag.BoolVar(&v, "v", false, "version")
	confFile := flag.String("c", "rport-pairing.conf", "config file")
	flag.Parse()
	if v {
		fmt.Println("rport-pairing", Version)
		os.Exit(0)
	}
	config := config.New(*confFile)
	c := cache.New()

	// Create request handlers
	depositHandler := &deposit.Handler{
		Cache:     c,
		ServerUrl: config.Server.Url,
	}
	installerHandler := &retrieve.InstallerHandler{
		StaticDeposit: config.StaticDeposit,
		Cache:         c,
	}
	updateHandler := &retrieve.UpdateHandler{
		StaticDeposit: config.StaticDeposit,
	}
	corsHandler := &cors.Handler{}

	// Tie handlers to routes and HTTP methods
	r := mux.NewRouter()
	r.PathPrefix("/").Methods("OPTIONS").Handler(corsHandler)
	r.Path("/").Methods("POST").Handler(depositHandler)
	r.Path("/update").Methods("GET").Handler(updateHandler)
	r.Path("/{pairingCode:[0-9 a-z A-Z]{7}}").Methods("GET").Handler(installerHandler)

	// Start the server
	log.Println("Server started on ", config.Server.Address)
	log.Fatal(http.ListenAndServe(config.Server.Address, r))

}
