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

type VehicleHandler struct {
	vehicles *service.VehicleService
	log      *slog.Logger
}

type vehicleRequest struct {
	Brand        string  `json:"brand" binding:"required" example:"Toyota"`
	Model        string  `json:"model" binding:"required" example:"Camry"`
	Year         int     `json:"year" binding:"required" example:"2020"`
	VIN          *string `json:"vin" example:"JTDBE32K620123456"`
	MileageKM    int     `json:"mileage_km" example:"42000"`
	FuelType     *string `json:"fuel_type" example:"petrol"`
	Transmission *string `json:"transmission" example:"automatic"`
	UsageType    *string `json:"usage_type" example:"mixed"`
}

type vehicleUpdateRequest struct {
	Brand        *string `json:"brand" example:"Toyota"`
	Model        *string `json:"model" example:"Camry"`
	Year         *int    `json:"year" example:"2021"`
	VIN          *string `json:"vin" example:"JTDBE32K620123456"`
	MileageKM    *int    `json:"mileage_km" example:"45000"`
	FuelType     *string `json:"fuel_type" example:"petrol"`
	Transmission *string `json:"transmission" example:"automatic"`
	UsageType    *string `json:"usage_type" example:"mixed"`
}

type vehicleListResponse struct {
	Vehicles []domain.Vehicle `json:"vehicles"`
}

func NewVehicleHandler(vehicles *service.VehicleService, log *slog.Logger) *VehicleHandler {
	if log == nil {
		log = slog.Default()
	}

	return &VehicleHandler{
		vehicles: vehicles,
		log:      log,
	}
}

// CreateVehicle godoc
// @Summary Create a vehicle
// @Description Creates a vehicle owned by the authenticated user.
// @Tags vehicles
// @Accept json
// @Produce json
// @Security BasicAuth
// @Param request body vehicleRequest true "Vehicle payload"
// @Success 201 {object} domain.Vehicle
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 409 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles [post]
func (h *VehicleHandler) CreateVehicle(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	var req vehicleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}

	vehicle, err := h.vehicles.Create(c.Request.Context(), user.ID, service.CreateVehicleInput{
		Brand:        req.Brand,
		Model:        req.Model,
		Year:         req.Year,
		VIN:          req.VIN,
		MileageKM:    req.MileageKM,
		FuelType:     req.FuelType,
		Transmission: req.Transmission,
		UsageType:    req.UsageType,
	})
	if err != nil {
		h.handleVehicleError(c, err)
		return
	}

	c.JSON(http.StatusCreated, vehicle)
}

// ListVehicle godoc
// @Summary List vehicles
// @Description Lists vehicles owned by the authenticated user.
// @Tags vehicles
// @Produce json
// @Security BasicAuth
// @Success 200 {object} vehicleListResponse
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles [get]
func (h *VehicleHandler) ListVehicle(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	vehicles, err := h.vehicles.List(c.Request.Context(), user.ID)
	if err != nil {
		h.handleVehicleError(c, err)
		return
	}

	c.JSON(http.StatusOK, vehicleListResponse{Vehicles: vehicles})
}

// GetVehicle godoc
// @Summary Get a vehicle
// @Description Gets a vehicle owned by the authenticated user.
// @Tags vehicles
// @Produce json
// @Security BasicAuth
// @Param id path int true "Vehicle ID"
// @Success 200 {object} domain.Vehicle
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles/{id} [get]
func (h *VehicleHandler) GetVehicle(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	id, ok := vehicleIDParam(c)
	if !ok {
		return
	}

	vehicle, err := h.vehicles.Get(c.Request.Context(), user.ID, id)
	if err != nil {
		h.handleVehicleError(c, err)
		return
	}

	c.JSON(http.StatusOK, vehicle)
}

// UpdateVehicle godoc
// @Summary Update a vehicle
// @Description Updates a vehicle owned by the authenticated user.
// @Tags vehicles
// @Accept json
// @Produce json
// @Security BasicAuth
// @Param id path int true "Vehicle ID"
// @Param request body vehicleUpdateRequest true "Vehicle patch payload"
// @Success 200 {object} domain.Vehicle
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 409 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles/{id} [patch]
func (h *VehicleHandler) UpdateVehicle(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	id, ok := vehicleIDParam(c)
	if !ok {
		return
	}

	var req vehicleUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}

	vehicle, err := h.vehicles.Update(c.Request.Context(), user.ID, id, service.UpdateVehicleInput{
		Brand:        req.Brand,
		Model:        req.Model,
		Year:         req.Year,
		VIN:          req.VIN,
		MileageKM:    req.MileageKM,
		FuelType:     req.FuelType,
		Transmission: req.Transmission,
		UsageType:    req.UsageType,
	})
	if err != nil {
		h.handleVehicleError(c, err)
		return
	}

	c.JSON(http.StatusOK, vehicle)
}

// DeleteVehicle godoc
// @Summary Delete a vehicle
// @Description Deletes a vehicle owned by the authenticated user.
// @Tags vehicles
// @Security BasicAuth
// @Param id path int true "Vehicle ID"
// @Success 204
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles/{id} [delete]
func (h *VehicleHandler) DeleteVehicle(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	id, ok := vehicleIDParam(c)
	if !ok {
		return
	}

	if err := h.vehicles.Delete(c.Request.Context(), user.ID, id); err != nil {
		h.handleVehicleError(c, err)
		return
	}

	c.Status(http.StatusNoContent)
}

func vehicleIDParam(c *gin.Context) (int64, bool) {
	id, err := strconv.ParseInt(c.Param("id"), migrationVersionBase, migrationVersionBit)
	if err != nil || id <= 0 {
		errorJSON(c, http.StatusBadRequest, "invalid vehicle id")
		return 0, false
	}

	return id, true
}

func (h *VehicleHandler) handleVehicleError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, service.ErrVehicleBrandRequired),
		errors.Is(err, service.ErrVehicleModelRequired),
		errors.Is(err, service.ErrVehicleInvalidMileage),
		errors.Is(err, service.ErrVehicleInvalidYear),
		errors.Is(err, service.ErrVehicleInvalidVIN):
		errorJSON(c, http.StatusBadRequest, err.Error())

	case errors.Is(err, repository.ErrNotFound):
		errorJSON(c, http.StatusNotFound, "vehicle not found")

	case errors.Is(err, repository.ErrConflict):
		errorJSON(c, http.StatusConflict, "vehicle conflicts with existing data")

	default:
		internalErrorJSON(c, h.log, "vehicle request failed", err)
	}
}
