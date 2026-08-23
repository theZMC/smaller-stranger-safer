// svc is the Go cameo for the Smaller, Stranger, Safer talk: a tiny HTTP
// service compiled to a static binary and shipped FROM scratch.
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]any{"ok": true})
	})

	// /check makes one outbound TLS call. In a bare FROM scratch image this
	// fails with a certificate error because there is no CA bundle; the certs
	// stage in the Dockerfile is what makes it work.
	http.HandleFunc("/check", func(w http.ResponseWriter, r *http.Request) {
		resp, err := http.Get("https://example.com")
		if err != nil {
			writeJSON(w, map[string]any{"tls": "failed", "error": err.Error()})
			return
		}
		resp.Body.Close()
		writeJSON(w, map[string]any{"tls": "ok", "status": resp.StatusCode})
	})

	log.Printf("svc listening on %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}
