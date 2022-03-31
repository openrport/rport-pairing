package main

import (
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
	config := config.New("rport-pairing.conf")
	c := cache.New()

	// Create request handlers
	depositHandler := &deposit.Handler{
		Cache:     c,
		ServerUrl: config.Server.Url,
	}
	retrieveHandler := &retrieve.Handler{
		DummyCode:     config.DummyCode,
		StaticDeposit: config.StaticDeposit,
		Cache:         c,
	}
	corsHandler := &cors.Handler{}

	// Tie handlers to routes and HTTP methods
	r := mux.NewRouter()
	r.PathPrefix("/").Methods("OPTIONS").Handler(corsHandler)
	r.Path("/").Methods("POST").Handler(depositHandler)
	r.Path("/update").Methods("GET").Handler(retrieveHandler)
	r.Path("/{pairingCode:[0-9 a-z A-Z]{7}}").Methods("GET").Handler(retrieveHandler)

	// Start the server
	log.Println("Server started on ", config.Server.Address)
	log.Fatal(http.ListenAndServe(config.Server.Address, r))

}
