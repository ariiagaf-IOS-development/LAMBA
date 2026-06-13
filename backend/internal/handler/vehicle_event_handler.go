package handler

import (
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/middleware"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/repository"
)

var (
	errInvalidEventType  = errors.New("event type must be one of: trip, refuel, repair, service")
	errEventTitleEmpty   = errors.New("title is required")
	errEventMileage      = errors.New("mileage_km must be greater than or equal to 0")
	errEventCost         = errors.New("cost must be greater than or equal to 0")
	errEventDateRequired = errors.New("event_date is required")
)

type VehicleEventHandler struct {
	events *repository.VehicleEventRepository
	log    *slog.Logger
}

type vehicleEventRequest struct {
	Type        domain.EventType `json:"type" binding:"required" example:"repair"`
	Title       string           `json:"title" binding:"required" example:"Замена масла"`
	Description *string          `json:"description" example:"Масло 5W-30, фильтр"`
	MileageKM   int              `json:"mileage_km" example:"124500"`
	Cost        float64          `json:"cost" example:"7500"`
	EventDate   time.Time        `json:"event_date" binding:"required" example:"2026-06-03T12:00:00Z"`
}

type vehicleEventsResponse struct {
	VehicleID int64                 `json:"vehicle_id"`
	Events    []domain.VehicleEvent `json:"events"`
}

type vehicleTimelineResponse struct {
	VehicleID int64                 `json:"vehicle_id"`
	Timeline  []domain.VehicleEvent `json:"timeline"`
}

type vehicleEventUpdateRequest struct {
	Type        *domain.EventType `json:"type" example:"repair" enums:"trip,refuel,repair,service"`
	Title       *string           `json:"title" example:"Замена масла"`
	Description *string           `json:"description" example:"Масло 5W-30, фильтр"`
	MileageKM   *int              `json:"mileage_km" example:"124500"`
	Cost        *float64          `json:"cost" example:"7500"`
	EventDate   *time.Time        `json:"event_date" example:"2026-06-03T12:00:00Z"`
}

func NewVehicleEventHandler(
	events *repository.VehicleEventRepository,
	log *slog.Logger,
) *VehicleEventHandler {
	if log == nil {
		log = slog.Default()
	}

	return &VehicleEventHandler{
		events: events,
		log:    log,
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

	event, err := newVehicleEventFromRequest(vehicleID, req)
	if err != nil {
		errorJSON(c, http.StatusBadRequest, err.Error())
		return
	}

	event, err = h.events.CreateForUser(c.Request.Context(), user.ID, event)
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

	events, err := h.events.ListByVehicleForUser(c.Request.Context(), user.ID, vehicleID)
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

	events, err := h.events.ListByVehicleForUser(c.Request.Context(), user.ID, vehicleID)
	if err != nil {
		h.handleVehicleEventError(c, err)
		return
	}

	c.JSON(http.StatusOK, vehicleTimelineResponse{
		VehicleID: vehicleID,
		Timeline:  events,
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

	update, err := validateVehicleEventUpdate(req)
	if err != nil {
		errorJSON(c, http.StatusBadRequest, err.Error())
		return
	}

	event, err := h.events.UpdateForUser(c.Request.Context(), user.ID, vehicleID, eventID, update)
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

	if err := h.events.DeleteForUser(c.Request.Context(), user.ID, vehicleID, eventID); err != nil {
		h.handleVehicleEventError(c, err)
		return
	}

	c.Status(http.StatusNoContent)
}

func newVehicleEventFromRequest(
	vehicleID int64,
	req vehicleEventRequest,
) (domain.VehicleEvent, error) {
	if !isValidEventType(req.Type) {
		return domain.VehicleEvent{}, errInvalidEventType
	}

	title := strings.TrimSpace(req.Title)
	if title == "" {
		return domain.VehicleEvent{}, errEventTitleEmpty
	}

	if req.MileageKM < 0 {
		return domain.VehicleEvent{}, errEventMileage
	}

	if req.Cost < 0 {
		return domain.VehicleEvent{}, errEventCost
	}

	if req.EventDate.IsZero() {
		return domain.VehicleEvent{}, errEventDateRequired
	}

	return domain.VehicleEvent{
		VehicleID:   vehicleID,
		Type:        req.Type,
		Title:       title,
		Description: normalizeOptionalString(req.Description),
		MileageKM:   req.MileageKM,
		Cost:        req.Cost,
		EventDate:   req.EventDate,
	}, nil
}

func isValidEventType(eventType domain.EventType) bool {
	switch eventType {
	case domain.EventTypeTrip,
		domain.EventTypeRefuel,
		domain.EventTypeRepair,
		domain.EventTypeService:
		return true
	default:
		return false
	}
}

func normalizeOptionalString(value *string) *string {
	if value == nil {
		return nil
	}

	trimmed := strings.TrimSpace(*value)
	if trimmed == "" {
		return nil
	}

	return &trimmed
}

func (h *VehicleEventHandler) handleVehicleEventError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, repository.ErrNotFound):
		errorJSON(c, http.StatusNotFound, "vehicle not found")
	default:
		h.log.ErrorContext(
			c.Request.Context(),
			"vehicle event request failed",
			slog.String("method", c.Request.Method),
			slog.String("path", c.FullPath()),
			slog.String("error", err.Error()),
		)

		errorJSON(c, http.StatusInternalServerError, "internal server error")
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

func validateVehicleEventUpdate(
	req vehicleEventUpdateRequest,
) (repository.VehicleEventUpdate, error) {
	var update repository.VehicleEventUpdate

	if req.Type != nil {
		if !isValidEventType(*req.Type) {
			return update, errInvalidEventType
		}
		update.Type = req.Type
	}

	if req.Title != nil {
		title := strings.TrimSpace(*req.Title)
		if title == "" {
			return update, errEventTitleEmpty
		}
		update.Title = &title
	}

	if req.Description != nil {
		update.Description.Set = true

		description := strings.TrimSpace(*req.Description)
		if description != "" {
			update.Description.Value = &description
		}
	}

	if req.MileageKM != nil {
		if *req.MileageKM < 0 {
			return update, errEventMileage
		}
		update.MileageKM = req.MileageKM
	}

	if req.Cost != nil {
		if *req.Cost < 0 {
			return update, errEventCost
		}
		update.Cost = req.Cost
	}

	if req.EventDate != nil {
		if req.EventDate.IsZero() {
			return update, errEventDateRequired
		}
		update.EventDate = req.EventDate
	}

	return update, nil
}
