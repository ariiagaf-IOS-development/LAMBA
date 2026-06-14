package handler

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"
)

type ErrorResponse struct {
	Error string `json:"error" example:"internal server error"`
}

func errorJSON(c *gin.Context, status int, message string) {
	c.JSON(status, ErrorResponse{Error: message})
}

func internalErrorJSON(c *gin.Context, log *slog.Logger, message string, err error) {
	if log == nil {
		log = slog.Default()
	}

	log.ErrorContext(
		c.Request.Context(),
		message,
		slog.String("method", c.Request.Method),
		slog.String("path", c.FullPath()),
		slog.String("error", err.Error()),
	)

	errorJSON(c, http.StatusInternalServerError, "internal server error")
}
