package handler

import (
	"context"
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type HealthResponse struct {
	Service string            `json:"service" example:"lamba-api"`
	Status  string            `json:"status" example:"ok"`
	Checks  map[string]string `json:"checks,omitempty"`
}

type HealthHandler struct {
	db *sql.DB
}

func NewHealthHandler(db *sql.DB) *HealthHandler {
	return &HealthHandler{db: db}
}

// Health godoc
// @Summary Check API health
// @Description Returns API liveness information and database readiness when configured.
// @Tags health
// @Produce json
// @Success 200 {object} HealthResponse
// @Failure 503 {object} HealthResponse
// @Router /health [get]
func (h *HealthHandler) Health(c *gin.Context) {
	checks := map[string]string{"api": "ok"}
	statusCode := http.StatusOK
	status := "ok"

	if h.db != nil {
		ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
		defer cancel()

		if err := h.db.PingContext(ctx); err != nil {
			checks["postgres"] = "unavailable"
			statusCode = http.StatusServiceUnavailable
			status = "degraded"
		} else {
			checks["postgres"] = "ok"
		}
	}

	c.JSON(statusCode, HealthResponse{
		Service: "lamba-api",
		Status:  status,
		Checks:  checks,
	})
}
