package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/application/service"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/http/middleware"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
)

const (
	migrationVersionBase = 10
	migrationVersionBit  = 64
)

type PredictionHandler struct {
	predictions *service.PredictionService
}

func NewPredictionHandler(predictions *service.PredictionService) *PredictionHandler {
	return &PredictionHandler{predictions: predictions}
}

type predictionsResponse struct {
	VehicleID   int64               `json:"vehicle_id"`
	Predictions []domain.Prediction `json:"predictions"`
}

// GetByVehicle godoc
// @Summary Get vehicle predictions
// @Description Returns latest predictions for vehicle parts. If predictions do not exist, backend generates and stores them.
// @Tags predictions
// @Produce json
// @Param id path int true "Vehicle ID"
// @Success 200 {object} predictionsResponse
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Security BasicAuth
// @Router /api/vehicles/{id}/predictions [get]
func (h *PredictionHandler) GetByVehicle(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	vehicleID, err := strconv.ParseInt(c.Param("id"), migrationVersionBase, migrationVersionBit)
	if err != nil || vehicleID <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid vehicle id"})
		return
	}

	predictions, err := h.predictions.GetOrGenerate(c.Request.Context(), user.ID, vehicleID)
	if errors.Is(err, repository.ErrNotFound) {
		c.JSON(http.StatusNotFound, gin.H{"error": "vehicle not found"})
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get predictions"})
		return
	}

	c.JSON(http.StatusOK, predictionsResponse{
		VehicleID:   vehicleID,
		Predictions: predictions,
	})
}
