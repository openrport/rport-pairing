package retrieve_test

import (
	"fmt"
	"github.com/cloudradar-monitoring/rport-pairing/deposit"
	"github.com/cloudradar-monitoring/rport-pairing/internal/cache"
	"github.com/cloudradar-monitoring/rport-pairing/retrieve"
	"github.com/gorilla/mux"
	"github.com/stretchr/testify/assert"
	"log"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

var tests = []struct {
	userAgent      string
	expected       string
	expectedStatus int
	pairingCode    string
}{
	{
		"curl/7.79.1",
		"BEGINNING of templates/linux/install.sh",
		200,
		"cZ1ZhsG",
	},
	{
		"curl/7.79.1",
		"BEGINNING of templates/linux/update.sh",
		200,
		"update",
	},
	{
		"curl/7.79.1",
		"/bin/sh -e",
		200,
		"C6esANp",
	},
	{
		"Mozilla/5.0 (Windows NT; Windows NT 10.0; en-US) WindowsPowerShell/5.1.20348.1",
		"function Expand-Zip {",
		200,
		"cZ1ZhsG",
	},
	{
		"Mozilla/5.0 (Windows NT; Windows NT 10.0; en-US) WindowsPowerShell/5.1.20348.1",
		"BEGINNING of templates/windows/update.ps1",
		200,
		"update",
	},
	{
		"go-test",
		"#No pairing found by pairing code abcdefg",
		404,
		"abcdefg",
	},
}

func TestHandler_ServeHTTP(t *testing.T) {
	c := cache.New()
	demoDeposit := deposit.Deposit{
		ConnectUrl:  "https://rport.example.com",
		Fingerprint: "2a:c1:71:09:80:ba:7c:10:05:e5:2c:99:6d:15:56:24",
		ClientId:    "client1",
		Password:    "foobaz",
	}
	// Store pairing data in the cache
	c.Set("C6esANp", demoDeposit, 10*time.Second)

	// Create the handler to be tested
	retrieveHandler := &retrieve.Handler{
		DummyCode:     "cZ1ZhsG",
		StaticDeposit: demoDeposit,
		Cache:         c,
	}

	for _, tc := range tests {
		log.Printf("Preparing test with code '%s' and User-Agent '%s'\n", tc.pairingCode, tc.userAgent)
		request, _ := http.NewRequest(http.MethodGet, "/"+tc.pairingCode, nil)
		// Simulate a URL like /0000000
		vars := map[string]string{
			"pairingCode": tc.pairingCode,
		}
		request.Header.Set("User-Agent", tc.userAgent)
		request = mux.SetURLVars(request, vars)
		recorder := httptest.NewRecorder()
		retrieveHandler.ServeHTTP(recorder, request)
		assert.Equal(t, tc.expectedStatus, recorder.Result().StatusCode)
		assert.Contains(t, recorder.Body.String(), tc.expected, fmt.Sprintf("Expexted key word '%s' missing.", tc.expected))
		log.Println("Got HTTP status code", recorder.Result().StatusCode)
		if recorder.Result().StatusCode != 200 {
			continue
		}
		// Check if the template has been rendered correctly and the deposit values are included
		if tc.pairingCode != "update" {
			assert.Contains(t, recorder.Body.String(), "Dynamically inserted variables", "Missing: 'Dynamically inserted variables'")
			assert.Contains(t, recorder.Body.String(), demoDeposit.ConnectUrl, "Connect URL not found "+demoDeposit.ConnectUrl)
			assert.Contains(t, recorder.Body.String(), demoDeposit.Fingerprint)
			assert.Contains(t, recorder.Body.String(), demoDeposit.ClientId)
			assert.Contains(t, recorder.Body.String(), demoDeposit.Password)
		}
		//fmt.Println(recorder.Body.String())
	}
}
