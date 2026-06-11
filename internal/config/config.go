package config

import "os"

type Config struct {
	HTTPAddr string
}

func Load() Config {
	return Config{
		HTTPAddr: httpAddr(),
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
