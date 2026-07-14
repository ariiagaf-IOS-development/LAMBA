package handler

import (
	"log/slog"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/application/service"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/http/middleware"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
)

type DashboardHandler struct {
	service *service.DashboardService
	log     *slog.Logger
}

func NewDashboardHandler(service *service.DashboardService, log *slog.Logger) *DashboardHandler {
	if log == nil {
		log = slog.Default()
	}
	return &DashboardHandler{
		service: service,
		log:     log,
	}
}

// GetDashboard godoc
// @Summary Get vehicle dashboard
// @Description Aggregated vehicle data: stats, events, predictions
// @Tags dashboard
// @Accept json
// @Produce json
// @Security BasicAuth
// @Param id path int true "Vehicle ID"
// @Success 200 {object} domain.VehicleDashboard
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles/{id}/dashboard [get]
func (h *DashboardHandler) GetDashboard(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	vehicleID, err := strconv.ParseInt(c.Param("id"), migrationVersionBase, migrationVersionBit)
	if err != nil || vehicleID <= 0 {
		errorJSON(c, http.StatusBadRequest, "invalid vehicle id")
		return
	}

	dashboard, err := h.service.Get(c.Request.Context(), user.ID, vehicleID)
	if err != nil {
		if err == repository.ErrNotFound {
			errorJSON(c, http.StatusNotFound, "vehicle not found")
			return
		}

		internalErrorJSON(c, nil, "failed to get dashboard", err)
		return
	}

	c.JSON(http.StatusOK, dashboard)
}
