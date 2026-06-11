package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type HealthResponse struct {
	Service string `json:"service" example:"lamba-api"`
	Status  string `json:"status" example:"ok"`
}

// Health godoc
// @Summary Check API health
// @Description Returns basic API liveness information.
// @Tags health
// @Produce json
// @Success 200 {object} HealthResponse
// @Router /health [get]
func Health(c *gin.Context) {
	c.JSON(http.StatusOK, HealthResponse{
		Service: "lamba-api",
		Status:  "ok",
	})
}
