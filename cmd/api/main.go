package main

import (
	"log"

	_ "gitlab.pg.innopolis.university/lamba/LAMBA/docs"
	"gitlab.pg.innopolis.university/lamba/LAMBA/internal/config"
	"gitlab.pg.innopolis.university/lamba/LAMBA/internal/router"
)

// @title LAMBA Backend API
// @version 0.1.0
// @description Backend API for the LAMBA vehicle maintenance MVP.
// @host localhost:8080
// @BasePath /
func main() {
	cfg := config.Load()
	r := router.New()

	log.Printf("starting LAMBA API on %s", cfg.HTTPAddr)
	if err := r.Run(cfg.HTTPAddr); err != nil {
		log.Fatalf("failed to start LAMBA API: %v", err)
	}
}
