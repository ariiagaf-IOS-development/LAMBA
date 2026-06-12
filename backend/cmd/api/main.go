package main

import (
	"context"
	"log/slog"
	"os"

	_ "gitlab.pg.innopolis.university/lamba/LAMBA/backend/docs"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/config"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/db"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/router"
)

func main() {
	ctx := context.Background()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	cfg := config.MustLoad()

	conn, err := db.Connect(ctx, cfg)
	if err != nil {
		logger.Error("failed to connect to PostgreSQL", slog.String("error", err.Error()))
		os.Exit(1)
	}
	defer conn.Close()

	if err := db.Migrate(ctx, conn); err != nil {
		logger.Error("failed to run migrations", slog.String("error", err.Error()))
		os.Exit(1)
	}

	r := router.New(router.Dependencies{
		Config: cfg,
		DB:     conn,
		Logger: logger,
	})

	logger.Info("starting LAMBA API", slog.String("addr", cfg.HTTPAddr))

	if err := r.Run(cfg.HTTPAddr); err != nil {
		logger.Error("failed to start LAMBA API", slog.String("error", err.Error()))
		os.Exit(1)
	}
}
