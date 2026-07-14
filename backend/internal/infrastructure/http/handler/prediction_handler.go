package handler

import (
	"errors"
	"log/slog"
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
	log         *slog.Logger
}

func NewPredictionHandler(predictions *service.PredictionService, log *slog.Logger) *PredictionHandler {
	if log == nil {
		log = slog.Default()
	}
	return &PredictionHandler{predictions: predictions, log: log}
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

// RefreshPredictions godoc
// @Summary Refresh vehicle predictions
// @Description Calls ML service to regenerate predictions for the vehicle, saves results, and returns updated predictions
// @Tags predictions
// @Produce json
// @Param id path int true "Vehicle ID"
// @Success 200 {object} predictionsResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Security BasicAuth
// @Router /api/vehicles/{id}/predictions/refresh [post]
func (h *PredictionHandler) RefreshPredictions(c *gin.Context) {
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

	predictions, err := h.predictions.Recalculate(c.Request.Context(), user.ID, vehicleID)
	if errors.Is(err, repository.ErrNotFound) {
		errorJSON(c, http.StatusNotFound, "vehicle not found")
		return
	}
	if err != nil {
		internalErrorJSON(c, h.log, "failed to refresh predictions", err)
		return
	}

	c.JSON(http.StatusOK, predictionsResponse{
		VehicleID:   vehicleID,
		Predictions: predictions,
	})
}

type pushPredictionsRequest struct {
	Predictions []domain.Prediction `json:"predictions" binding:"required"`
}

// PushPredictions godoc
// @Summary Push predictions from ML service
// @Description Internal endpoint (no auth) for ML service to push predictions directly
// @Tags predictions-internal
// @Accept json
// @Produce json
// @Param id path int true "Vehicle ID"
// @Param request body pushPredictionsRequest true "Predictions to save"
// @Success 200 {object} predictionsResponse
// @Failure 400 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/internal/vehicles/{id}/predictions [post]
func (h *PredictionHandler) PushPredictions(c *gin.Context) {
	vehicleID, err := strconv.ParseInt(c.Param("id"), migrationVersionBase, migrationVersionBit)
	if err != nil || vehicleID <= 0 {
		errorJSON(c, http.StatusBadRequest, "invalid vehicle id")
		return
	}

	var req pushPredictionsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}

	saved, err := h.predictions.SaveForVehicle(c.Request.Context(), vehicleID, req.Predictions)
	if errors.Is(err, repository.ErrNotFound) {
		errorJSON(c, http.StatusNotFound, "vehicle not found")
		return
	}
	if err != nil {
		internalErrorJSON(c, h.log, "failed to push predictions", err)
		return
	}

	c.JSON(http.StatusOK, predictionsResponse{
		VehicleID:   vehicleID,
		Predictions: saved,
	})
}
