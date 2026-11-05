package main

import (
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/MuRanSea/DramaRed/apps/windows/daemon/internal/api"
	"github.com/MuRanSea/DramaRed/apps/windows/daemon/internal/ohg"
	"github.com/MuRanSea/DramaRed/apps/windows/daemon/internal/store"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:17890", "listen address (localhost only)")
	deviceFile := flag.String("device", "anonymous.json", "openhongguo anonymous device profile path")
	dataDir := flag.String("data", ".", "local history/favorites JSON directory")
	flag.Parse()

	if err := os.MkdirAll(*dataDir, 0o700); err != nil {
		log.Fatalf("data dir: %v", err)
	}

	client, err := ohg.New(*deviceFile)
	if err != nil {
		log.Fatalf("ohg client: %v", err)
	}
	defer client.Close()

	hist := store.NewHistory(*dataDir)
	favs := store.NewFavorites(*dataDir)
	srv := api.NewServer(client, hist, favs)

	httpServer := &http.Server{Addr: *addr, Handler: srv.Handler()}
	go func() {
		log.Printf("drama-daemon listening on http://%s (openhongguo v0.2.0)", *addr)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	<-ch
	log.Printf("shutting down")
	_ = httpServer.Close()
}
