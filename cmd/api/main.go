package main

import (
	"context"
	"log"

	_ "gitlab.pg.innopolis.university/lamba/LAMBA/docs"
	"gitlab.pg.innopolis.university/lamba/LAMBA/internal/config"
	"gitlab.pg.innopolis.university/lamba/LAMBA/internal/db"
	"gitlab.pg.innopolis.university/lamba/LAMBA/internal/router"
)

// @title LAMBA Backend API
// @version 0.1.0
// @description Backend API for the LAMBA vehicle maintenance MVP.
// @host localhost:8080
// @BasePath /
// @securityDefinitions.basic BasicAuth
func main() {
	ctx := context.Background()
	cfg := config.Load()

	conn, err := db.Connect(ctx, cfg)
	if err != nil {
		log.Fatalf("failed to connect to PostgreSQL: %v", err)
	}
	defer conn.Close()

	if err := db.Migrate(ctx, conn); err != nil {
		log.Fatalf("failed to run migrations: %v", err)
	}

	r := router.New(router.Dependencies{
		Config: cfg,
		DB:     conn,
	})

	log.Printf("starting LAMBA API on %s", cfg.HTTPAddr)
	if err := r.Run(cfg.HTTPAddr); err != nil {
		log.Fatalf("failed to start LAMBA API: %v", err)
	}
}
