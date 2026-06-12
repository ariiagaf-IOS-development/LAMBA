package config

import (
	"os"
	"strconv"
)

const (
	defaultDatabaseURL = "postgres://lamba:lamba@localhost:5432/lamba?sslmode=disable"
	defaultBcryptCost  = 12
)

type Config struct {
	HTTPAddr    string
	DatabaseURL string
	BcryptCost  int
}

func Load() Config {
	return Config{
		HTTPAddr:    httpAddr(),
		DatabaseURL: stringEnv("DATABASE_URL", defaultDatabaseURL),
		BcryptCost:  intEnv("BCRYPT_COST", defaultBcryptCost),
	}
}

func httpAddr() string {
	if value := os.Getenv("HTTP_ADDR"); value != "" {
		return value
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	return ":" + port
}

func stringEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}

	return fallback
}

func intEnv(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil || parsed < 4 || parsed > 31 {
		return fallback
	}

	return parsed
}
