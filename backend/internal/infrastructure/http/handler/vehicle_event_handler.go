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

type VehicleEventHandler struct {
	events   *service.VehicleEventService
	timeline *service.TimelineService
	log      *slog.Logger
}

type vehicleEventRequest struct {
	Type        domain.EventType `json:"type" binding:"required" example:"repair"`
	Title       string           `json:"title" binding:"required" example:"Замена масла"`
	Description *string          `json:"description" example:"Масло 5W-30, фильтр"`
	MileageKM   int              `json:"mileage_km" example:"124500"`
	Cost        float64          `json:"cost" example:"7500"`
	EventDate   time.Time        `json:"event_date" binding:"required" example:"2026-06-03T12:00:00Z"`
	Metadata    map[string]any   `json:"metadata,omitempty"`
}

type vehicleEventUpdateRequest struct {
	Type        *domain.EventType `json:"type" example:"repair" enums:"trip,refuel,repair,service"`
	Title       *string           `json:"title" example:"Замена масла"`
	Description *string           `json:"description" example:"Масло 5W-30, фильтр"`
	MileageKM   *int              `json:"mileage_km" example:"124500"`
	Cost        *float64          `json:"cost" example:"7500"`
	EventDate   *time.Time        `json:"event_date" example:"2026-06-03T12:00:00Z"`
	Metadata    map[string]any    `json:"metadata,omitempty"`
}

type vehicleEventsResponse struct {
	VehicleID int64                 `json:"vehicle_id"`
	Events    []domain.VehicleEvent `json:"events"`
}

type vehicleTimelineResponse struct {
	VehicleID int64                 `json:"vehicle_id"`
	Timeline  []domain.VehicleEvent `json:"timeline"`
}

func NewVehicleEventHandler(
	events *service.VehicleEventService,
	timeline *service.TimelineService,
	log *slog.Logger,
) *VehicleEventHandler {
	if log == nil {
		log = slog.Default()
	}

	return &VehicleEventHandler{
		events:   events,
		timeline: timeline,
		log:      log,
	}
}

// CreateEvent godoc
// @Summary Create a vehicle event
// @Description Creates a lifecycle event for a vehicle owned by the authenticated user.
// @Tags vehicle-events
// @Accept json
// @Produce json
// @Security BasicAuth
// @Param id path int true "Vehicle ID"
// @Param request body vehicleEventRequest true "Vehicle event payload"
// @Success 201 {object} domain.VehicleEvent
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles/{id}/events [post]
func (h *VehicleEventHandler) CreateEvent(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	vehicleID, ok := vehicleIDParam(c)
	if !ok {
		return
	}

	var req vehicleEventRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}

	event, err := h.events.Create(c.Request.Context(), user.ID, vehicleID, service.CreateVehicleEventInput{
		Type:        req.Type,
		Title:       req.Title,
		Description: req.Description,
		MileageKM:   req.MileageKM,
		Cost:        req.Cost,
		EventDate:   req.EventDate,
		Metadata:    req.Metadata,
	})
	if err != nil {
		h.handleVehicleEventError(c, err)
		return
	}

	c.JSON(http.StatusCreated, event)
}

// ListEvents godoc
// @Summary List vehicle events
// @Description Lists lifecycle events for a vehicle owned by the authenticated user.
// @Tags vehicle-events
// @Produce json
// @Security BasicAuth
// @Param id path int true "Vehicle ID"
// @Success 200 {object} vehicleEventsResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles/{id}/events [get]
func (h *VehicleEventHandler) ListEvents(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	vehicleID, ok := vehicleIDParam(c)
	if !ok {
		return
	}

	events, err := h.events.List(c.Request.Context(), user.ID, vehicleID)
	if err != nil {
		h.handleVehicleEventError(c, err)
		return
	}

	c.JSON(http.StatusOK, vehicleEventsResponse{
		VehicleID: vehicleID,
		Events:    events,
	})
}

// GetTimeline godoc
// @Summary Get vehicle timeline
// @Description Returns the basic vehicle timeline based on lifecycle events.
// @Tags vehicle-events
// @Produce json
// @Security BasicAuth
// @Param id path int true "Vehicle ID"
// @Success 200 {object} vehicleTimelineResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles/{id}/timeline [get]
func (h *VehicleEventHandler) GetTimeline(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	vehicleID, ok := vehicleIDParam(c)
	if !ok {
		return
	}

	timeline, err := h.timeline.GetByVehicle(c.Request.Context(), user.ID, vehicleID)
	if err != nil {
		h.handleVehicleEventError(c, err)
		return
	}

	c.JSON(http.StatusOK, vehicleTimelineResponse{
		VehicleID: vehicleID,
		Timeline:  timeline,
	})
}

// UpdateEvent godoc
// @Summary Update a vehicle event
// @Description Updates a lifecycle event for a vehicle owned by the authenticated user.
// @Tags vehicle-events
// @Accept json
// @Produce json
// @Security BasicAuth
// @Param id path int true "Vehicle ID"
// @Param eventId path int true "Event ID"
// @Param request body vehicleEventUpdateRequest true "Vehicle event patch payload"
// @Success 200 {object} domain.VehicleEvent
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles/{id}/events/{eventId} [patch]
func (h *VehicleEventHandler) UpdateEvent(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	vehicleID, ok := vehicleIDParam(c)
	if !ok {
		return
	}

	eventID, ok := eventIDParam(c)
	if !ok {
		return
	}

	var req vehicleEventUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}

	event, err := h.events.Update(c.Request.Context(), user.ID, vehicleID, eventID, service.UpdateVehicleEventInput{
		Type:        req.Type,
		Title:       req.Title,
		Description: req.Description,
		MileageKM:   req.MileageKM,
		Cost:        req.Cost,
		EventDate:   req.EventDate,
		Metadata:    req.Metadata,
	})
	if err != nil {
		h.handleVehicleEventError(c, err)
		return
	}

	c.JSON(http.StatusOK, event)
}

// DeleteEvent godoc
// @Summary Delete a vehicle event
// @Description Deletes a lifecycle event for a vehicle owned by the authenticated user.
// @Tags vehicle-events
// @Security BasicAuth
// @Param id path int true "Vehicle ID"
// @Param eventId path int true "Event ID"
// @Success 204
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles/{id}/events/{eventId} [delete]
func (h *VehicleEventHandler) DeleteEvent(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	vehicleID, ok := vehicleIDParam(c)
	if !ok {
		return
	}

	eventID, ok := eventIDParam(c)
	if !ok {
		return
	}

	if err := h.events.Delete(c.Request.Context(), user.ID, vehicleID, eventID); err != nil {
		h.handleVehicleEventError(c, err)
		return
	}

	c.Status(http.StatusNoContent)
}

func (h *VehicleEventHandler) handleVehicleEventError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, service.ErrVehicleEventInvalidType),
		errors.Is(err, service.ErrVehicleEventTitleEmpty),
		errors.Is(err, service.ErrVehicleEventMileage),
		errors.Is(err, service.ErrVehicleEventCost),
		errors.Is(err, service.ErrVehicleEventDateRequired):
		errorJSON(c, http.StatusBadRequest, err.Error())

	case errors.Is(err, repository.ErrNotFound):
		errorJSON(c, http.StatusNotFound, "vehicle or event not found")

	case errors.Is(err, repository.ErrConflict):
		errorJSON(c, http.StatusConflict, "vehicle event conflicts with existing data")

	default:
		internalErrorJSON(c, h.log, "vehicle event request failed", err)
	}
}

func eventIDParam(c *gin.Context) (int64, bool) {
	id, err := strconv.ParseInt(c.Param("eventId"), 10, 64)
	if err != nil || id <= 0 {
		errorJSON(c, http.StatusBadRequest, "invalid event id")
		return 0, false
	}

	return id, true
}
