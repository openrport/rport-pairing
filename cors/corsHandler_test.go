package cors_test

import (
	"github.com/openrport/rport-pairing/cors"
	"github.com/stretchr/testify/assert"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHandler_ServeHTTP(t *testing.T) {
	request, _ := http.NewRequest(http.MethodOptions, "/", nil)

	// Create the handler to be tested
	corsHandler := cors.Handler{}

	recorder := httptest.NewRecorder()
	corsHandler.ServeHTTP(recorder, request)
	assert.Equal(t, 204, recorder.Result().StatusCode)
	assert.Contains(t,
		recorder.Result().Header.Get("Access-Control-Allow-Origin"),
		"*",
	)
	assert.Contains(t,
		recorder.Result().Header.Get("Access-Control-Allow-Methods"),
		"POST, GET, OPTIONS",
	)
	assert.Contains(t,
		recorder.Result().Header.Get("Access-Control-Allow-Headers"),
		"Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With",
	)
}
