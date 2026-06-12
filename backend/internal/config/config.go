package config

import (
	"log"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	HTTPAddr    string
	DatabaseURL string
	BcryptCost  int
}

const (
	envHTTPAddr    = "HTTP_ADDR"
	envPort        = "PORT"
	envDatabaseURL = "DATABASE_URL"
	envBcryptCost  = "BCRYPT_COST"
)

const (
	defaultPort        = "8080"
	defaultDatabaseURL = "postgres://lamba:lamba@localhost:5432/lamba?sslmode=disable"
	defaultBcryptCost  = 12
)

const (
	minBcryptCost = 4
	maxBcryptCost = 31
)

func MustLoad() Config {
	if err := godotenv.Load(); err != nil {
		log.Println("no .env file found")
	}

	return Config{
		HTTPAddr:    loadHTTPAddr(),
		DatabaseURL: getEnv(envDatabaseURL, defaultDatabaseURL),
		BcryptCost:  getEnvIntInRange(envBcryptCost, defaultBcryptCost, minBcryptCost, maxBcryptCost),
	}
}

func loadHTTPAddr() string {
	if value := os.Getenv(envHTTPAddr); value != "" {
		return value
	}

	return ":" + getEnv(envPort, defaultPort)
}

func getEnv(key string, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}

	return value
}

func getEnvIntInRange(key string, defaultValue, minValue, maxValue int) int {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		log.Fatalf("invalid int value for %s: %s", key, value)
	}

	if parsed < minValue || parsed > maxValue {
		log.Fatalf("%s must be between %d and %d", key, minValue, maxValue)
	}

	return parsed
}
