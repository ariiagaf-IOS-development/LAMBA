package handler

import (
	"context"
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

const (
	serviceName = "lamba-api"

	checkAPI      = "api"
	checkPostgres = "postgres"

	statusOK          = "ok"
	statusUnavailable = "unavailable"
	statusDegraded    = "degraded"

	healthTimeout = 2 * time.Second
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

// CheckHealth godoc
// @Summary Check API health
// @Description Returns API liveness information and database readiness when configured.
// @Tags health
// @Produce json
// @Success 200 {object} HealthResponse
// @Failure 503 {object} HealthResponse
// @Router /health [get]
func (h *HealthHandler) CheckHealth(c *gin.Context) {
	checks := map[string]string{
		checkAPI: statusOK,
	}

	statusCode := http.StatusOK
	status := statusOK

	if h.db != nil {
		ctx, cancel := context.WithTimeout(c.Request.Context(), healthTimeout)
		defer cancel()

		if err := h.db.PingContext(ctx); err != nil {
			checks[checkPostgres] = statusUnavailable
			statusCode = http.StatusServiceUnavailable
			status = statusDegraded
		} else {
			checks[checkPostgres] = statusOK
		}
	}

	c.JSON(statusCode, HealthResponse{
		Service: serviceName,
		Status:  status,
		Checks:  checks,
	})
}
