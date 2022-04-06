package main

import (
	"flag"
	"github.com/cloudradar-monitoring/rport-pairing/cors"
	"github.com/cloudradar-monitoring/rport-pairing/deposit"
	"github.com/cloudradar-monitoring/rport-pairing/internal/cache"
	"github.com/cloudradar-monitoring/rport-pairing/internal/config"
	"github.com/cloudradar-monitoring/rport-pairing/retrieve"
	"github.com/gorilla/mux"
	"log"
	"net/http"
)

func main() {
	confFile := flag.String("c", "rport-pairing.conf", "config file")
	flag.Parse()
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
