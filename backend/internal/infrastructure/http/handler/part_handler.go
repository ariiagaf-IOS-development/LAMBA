package handler

import (
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/application/service"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/http/middleware"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
)

type PartHandler struct {
	parts *service.PartService
	log   *slog.Logger
}

func NewPartHandler(parts *service.PartService, log *slog.Logger) *PartHandler {
	if log == nil {
		log = slog.Default()
	}
	return &PartHandler{parts: parts, log: log}
}

type catalogResponse struct {
	Parts []domain.PartCatalogItem `json:"parts"`
}

type vehiclePartsResponse struct {
	Parts []domain.VehiclePart `json:"parts"`
}

type createPartRequest struct {
	CatalogCode          *string `json:"catalog_code" example:"engine_oil"`
	Name                 string  `json:"name" binding:"required" example:"Engine oil"`
	Category             *string `json:"category" example:"fluids"`
	InstalledAtMileageKM *int    `json:"installed_at_mileage_km" example:"40000"`
	LastServiceMileageKM *int    `json:"last_service_mileage_km" example:"40000"`
	LastServiceDate      *string `json:"last_service_date" example:"2025-01-15T00:00:00Z"`
}

// ListCatalog godoc
// @Summary List parts catalog
// @Description Returns all available parts from the catalog
// @Tags parts
// @Produce json
// @Success 200 {object} catalogResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/parts/catalog [get]
func (h *PartHandler) ListCatalog(c *gin.Context) {
	catalog, err := h.parts.ListCatalog(c.Request.Context())
	if err != nil {
		internalErrorJSON(c, h.log, "failed to list parts catalog", err)
		return
	}

	c.JSON(http.StatusOK, catalogResponse{Parts: catalog})
}

// ListByVehicle godoc
// @Summary List vehicle parts
// @Description Returns all parts installed on a vehicle
// @Tags parts
// @Produce json
// @Security BasicAuth
// @Param id path int true "Vehicle ID"
// @Success 200 {object} vehiclePartsResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles/{id}/parts [get]
func (h *PartHandler) ListByVehicle(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	vehicleID, ok := vehicleIDParam(c)
	if !ok {
		return
	}

	parts, err := h.parts.ListByVehicle(c.Request.Context(), user.ID, vehicleID)
	if errors.Is(err, repository.ErrNotFound) {
		errorJSON(c, http.StatusNotFound, "vehicle not found")
		return
	}
	if err != nil {
		internalErrorJSON(c, h.log, "failed to list vehicle parts", err)
		return
	}

	c.JSON(http.StatusOK, vehiclePartsResponse{Parts: parts})
}

// CreatePart godoc
// @Summary Add a part to a vehicle
// @Description Creates a new part record for the specified vehicle
// @Tags parts
// @Accept json
// @Produce json
// @Security BasicAuth
// @Param id path int true "Vehicle ID"
// @Param request body createPartRequest true "Part payload"
// @Success 201 {object} domain.VehiclePart
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles/{id}/parts [post]
func (h *PartHandler) CreatePart(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	vehicleID, ok := vehicleIDParam(c)
	if !ok {
		return
	}

	var req createPartRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}

	input := repository.CreateVehiclePartInput{
		VehicleID:            vehicleID,
		CatalogCode:          req.CatalogCode,
		Name:                 req.Name,
		Category:             req.Category,
		InstalledAtMileageKM: req.InstalledAtMileageKM,
		LastServiceMileageKM: req.LastServiceMileageKM,
	}

	if req.LastServiceDate != nil {
		t, err := parseTime(*req.LastServiceDate)
		if err != nil {
			errorJSON(c, http.StatusBadRequest, "invalid last_service_date format")
			return
		}
		input.LastServiceDate = &t
	}

	part, err := h.parts.Create(c.Request.Context(), user.ID, input)
	if errors.Is(err, repository.ErrNotFound) {
		errorJSON(c, http.StatusNotFound, "vehicle not found")
		return
	}
	if err != nil {
		internalErrorJSON(c, h.log, "failed to create vehicle part", err)
		return
	}

	c.JSON(http.StatusCreated, part)
}

// DeletePart godoc
// @Summary Delete a vehicle part
// @Description Removes a part from the vehicle
// @Tags parts
// @Security BasicAuth
// @Param id path int true "Vehicle ID"
// @Param partId path int true "Part ID"
// @Success 204
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles/{id}/parts/{partId} [delete]
func (h *PartHandler) DeletePart(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	vehicleID, ok := vehicleIDParam(c)
	if !ok {
		return
	}

	partID, err := strconv.ParseInt(c.Param("partId"), migrationVersionBase, migrationVersionBit)
	if err != nil || partID <= 0 {
		errorJSON(c, http.StatusBadRequest, "invalid part id")
		return
	}

	if err := h.parts.Delete(c.Request.Context(), user.ID, vehicleID, partID); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			errorJSON(c, http.StatusNotFound, "part not found")
			return
		}
		internalErrorJSON(c, h.log, "failed to delete vehicle part", err)
		return
	}

	c.Status(http.StatusNoContent)
}

func parseTime(s string) (time.Time, error) {
	return time.Parse(time.RFC3339, s)
}
