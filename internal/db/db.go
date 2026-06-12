package db

import (
	"context"
	"database/sql"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
	"gitlab.pg.innopolis.university/lamba/LAMBA/internal/config"
)

func Connect(ctx context.Context, cfg config.Config) (*sql.DB, error) {
	conn, err := sql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}

	conn.SetMaxOpenConns(10)
	conn.SetMaxIdleConns(5)
	conn.SetConnMaxLifetime(30 * time.Minute)

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	if err := conn.PingContext(pingCtx); err != nil {
		conn.Close()
		return nil, err
	}

	return conn, nil
}
