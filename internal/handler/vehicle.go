package handler

import (
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gitlab.pg.innopolis.university/lamba/LAMBA/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/internal/middleware"
	"gitlab.pg.innopolis.university/lamba/LAMBA/internal/repository"
)

type VehicleHandler struct {
	vehicles *repository.VehicleRepository
}

type vehicleRequest struct {
	Brand     string  `json:"brand" binding:"required" example:"Toyota"`
	Model     string  `json:"model" binding:"required" example:"Camry"`
	Year      int     `json:"year" binding:"required" example:"2020"`
	VIN       *string `json:"vin" example:"JTDBE32K620123456"`
	MileageKM int     `json:"mileage_km" example:"42000"`
}

type vehicleUpdateRequest struct {
	Brand     *string `json:"brand" example:"Toyota"`
	Model     *string `json:"model" example:"Camry"`
	Year      *int    `json:"year" example:"2021"`
	VIN       *string `json:"vin" example:"JTDBE32K620123456"`
	MileageKM *int    `json:"mileage_km" example:"45000"`
}

type vehicleListResponse struct {
	Vehicles []domain.Vehicle `json:"vehicles"`
}

func NewVehicleHandler(vehicles *repository.VehicleRepository) *VehicleHandler {
	return &VehicleHandler{vehicles: vehicles}
}

// Create godoc
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
func (h *VehicleHandler) Create(c *gin.Context) {
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

	brand, model, vin, err := validateVehicle(req.Brand, req.Model, req.Year, req.MileageKM, req.VIN)
	if err != nil {
		errorJSON(c, http.StatusBadRequest, err.Error())
		return
	}

	vehicle, err := h.vehicles.Create(c.Request.Context(), domain.Vehicle{
		UserID:    user.ID,
		Brand:     brand,
		Model:     model,
		Year:      req.Year,
		VIN:       vin,
		MileageKM: req.MileageKM,
	})
	if err != nil {
		handleVehicleError(c, err)
		return
	}

	c.JSON(http.StatusCreated, vehicle)
}

// List godoc
// @Summary List vehicles
// @Description Lists vehicles owned by the authenticated user.
// @Tags vehicles
// @Produce json
// @Security BasicAuth
// @Success 200 {object} vehicleListResponse
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles [get]
func (h *VehicleHandler) List(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	vehicles, err := h.vehicles.ListByUser(c.Request.Context(), user.ID)
	if err != nil {
		handleVehicleError(c, err)
		return
	}

	c.JSON(http.StatusOK, vehicleListResponse{Vehicles: vehicles})
}

// Get godoc
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
func (h *VehicleHandler) Get(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	id, ok := vehicleIDParam(c)
	if !ok {
		return
	}

	vehicle, err := h.vehicles.GetByIDForUser(c.Request.Context(), user.ID, id)
	if err != nil {
		handleVehicleError(c, err)
		return
	}

	c.JSON(http.StatusOK, vehicle)
}

// Update godoc
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
func (h *VehicleHandler) Update(c *gin.Context) {
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

	update, err := validateVehicleUpdate(req)
	if err != nil {
		errorJSON(c, http.StatusBadRequest, err.Error())
		return
	}

	vehicle, err := h.vehicles.Update(c.Request.Context(), user.ID, id, update)
	if err != nil {
		handleVehicleError(c, err)
		return
	}

	c.JSON(http.StatusOK, vehicle)
}

// Delete godoc
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
func (h *VehicleHandler) Delete(c *gin.Context) {
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
		handleVehicleError(c, err)
		return
	}

	c.Status(http.StatusNoContent)
}

func vehicleIDParam(c *gin.Context) (int64, bool) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil || id <= 0 {
		errorJSON(c, http.StatusBadRequest, "invalid vehicle id")
		return 0, false
	}

	return id, true
}

func validateVehicle(brand, model string, year, mileageKM int, vin *string) (string, string, *string, error) {
	brand = strings.TrimSpace(brand)
	model = strings.TrimSpace(model)
	if brand == "" {
		return "", "", nil, errors.New("brand is required")
	}
	if model == "" {
		return "", "", nil, errors.New("model is required")
	}
	if err := validateYear(year); err != nil {
		return "", "", nil, err
	}
	if mileageKM < 0 {
		return "", "", nil, errors.New("mileage_km must be greater than or equal to 0")
	}

	return brand, model, normalizeVIN(vin), nil
}

func validateVehicleUpdate(req vehicleUpdateRequest) (repository.VehicleUpdate, error) {
	var update repository.VehicleUpdate

	if req.Brand != nil {
		brand := strings.TrimSpace(*req.Brand)
		if brand == "" {
			return repository.VehicleUpdate{}, errors.New("brand is required")
		}
		update.Brand = &brand
	}

	if req.Model != nil {
		model := strings.TrimSpace(*req.Model)
		if model == "" {
			return repository.VehicleUpdate{}, errors.New("model is required")
		}
		update.Model = &model
	}

	if req.Year != nil {
		if err := validateYear(*req.Year); err != nil {
			return repository.VehicleUpdate{}, err
		}
		update.Year = req.Year
	}

	if req.VIN != nil {
		vin := strings.TrimSpace(*req.VIN)
		update.VIN = &vin
	}

	if req.MileageKM != nil {
		if *req.MileageKM < 0 {
			return repository.VehicleUpdate{}, errors.New("mileage_km must be greater than or equal to 0")
		}
		update.MileageKM = req.MileageKM
	}

	return update, nil
}

func validateYear(year int) error {
	currentMax := time.Now().Year() + 1
	if year < 1886 || year > currentMax {
		return errors.New("year must be between 1886 and next calendar year")
	}

	return nil
}

func normalizeVIN(vin *string) *string {
	if vin == nil {
		return nil
	}

	trimmed := strings.TrimSpace(*vin)
	if trimmed == "" {
		return nil
	}

	return &trimmed
}

func handleVehicleError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, repository.ErrNotFound):
		errorJSON(c, http.StatusNotFound, "vehicle not found")
	case errors.Is(err, repository.ErrConflict):
		errorJSON(c, http.StatusConflict, "vehicle conflicts with existing data")
	default:
		errorJSON(c, http.StatusInternalServerError, "internal server error")
	}
}
