package service

import (
	"context"
	"errors"
	"strings"
	"time"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
)

var (
	ErrVehicleEventInvalidType  = errors.New("event type must be one of: trip, refuel, repair, service")
	ErrVehicleEventTitleEmpty   = errors.New("title is required")
	ErrVehicleEventMileage      = errors.New("mileage_km must be greater than or equal to 0")
	ErrVehicleEventCost         = errors.New("cost must be greater than or equal to 0")
	ErrVehicleEventDateRequired = errors.New("event_date is required")
)

type VehicleEventService struct {
	events *repository.VehicleEventRepository
}

type CreateVehicleEventInput struct {
	Type        domain.EventType
	Title       string
	Description *string
	MileageKM   int
	Cost        float64
	EventDate   time.Time
	Metadata    map[string]any
}

type UpdateVehicleEventInput struct {
	Type        *domain.EventType
	Title       *string
	Description *string
	MileageKM   *int
	Cost        *float64
	EventDate   *time.Time
	Metadata    map[string]any
}

func NewVehicleEventService(events *repository.VehicleEventRepository) *VehicleEventService {
	return &VehicleEventService{events: events}
}

func (s *VehicleEventService) Create(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	input CreateVehicleEventInput,
) (domain.VehicleEvent, error) {
	event, err := newVehicleEventFromInput(vehicleID, input)
	if err != nil {
		return domain.VehicleEvent{}, err
	}

	return s.events.CreateForUser(ctx, userID, event)
}

func (s *VehicleEventService) List(
	ctx context.Context,
	userID int64,
	vehicleID int64,
) ([]domain.VehicleEvent, error) {
	return s.events.ListByVehicleForUser(ctx, userID, vehicleID)
}

func (s *VehicleEventService) Get(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	eventID int64,
) (domain.VehicleEvent, error) {
	return s.events.GetByIDForUser(ctx, userID, vehicleID, eventID)
}

func (s *VehicleEventService) Update(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	eventID int64,
	input UpdateVehicleEventInput,
) (domain.VehicleEvent, error) {
	update, err := newVehicleEventUpdateFromInput(input)
	if err != nil {
		return domain.VehicleEvent{}, err
	}

	return s.events.UpdateForUser(ctx, userID, vehicleID, eventID, update)
}

func (s *VehicleEventService) Delete(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	eventID int64,
) error {
	return s.events.DeleteForUser(ctx, userID, vehicleID, eventID)
}

func newVehicleEventFromInput(
	vehicleID int64,
	input CreateVehicleEventInput,
) (domain.VehicleEvent, error) {
	if !isValidEventType(input.Type) {
		return domain.VehicleEvent{}, ErrVehicleEventInvalidType
	}

	title := strings.TrimSpace(input.Title)
	if title == "" {
		return domain.VehicleEvent{}, ErrVehicleEventTitleEmpty
	}

	if input.MileageKM < 0 {
		return domain.VehicleEvent{}, ErrVehicleEventMileage
	}

	if input.Cost < 0 {
		return domain.VehicleEvent{}, ErrVehicleEventCost
	}

	if input.EventDate.IsZero() {
		return domain.VehicleEvent{}, ErrVehicleEventDateRequired
	}

	return domain.VehicleEvent{
		VehicleID:   vehicleID,
		Type:        input.Type,
		Title:       title,
		Description: normalizeOptionalString(input.Description),
		MileageKM:   input.MileageKM,
		Cost:        input.Cost,
		EventDate:   input.EventDate,
		Metadata:    normalizeMetadata(input.Metadata),
	}, nil
}

func newVehicleEventUpdateFromInput(
	input UpdateVehicleEventInput,
) (repository.VehicleEventUpdate, error) {
	var update repository.VehicleEventUpdate

	if input.Type != nil {
		if !isValidEventType(*input.Type) {
			return update, ErrVehicleEventInvalidType
		}

		update.Type = input.Type
	}

	if input.Title != nil {
		title := strings.TrimSpace(*input.Title)
		if title == "" {
			return update, ErrVehicleEventTitleEmpty
		}

		update.Title = &title
	}

	if input.Description != nil {
		update.Description.Set = true
		update.Description.Value = normalizeOptionalString(input.Description)
	}

	if input.MileageKM != nil {
		if *input.MileageKM < 0 {
			return update, ErrVehicleEventMileage
		}

		update.MileageKM = input.MileageKM
	}

	if input.Cost != nil {
		if *input.Cost < 0 {
			return update, ErrVehicleEventCost
		}

		update.Cost = input.Cost
	}

	if input.EventDate != nil {
		if input.EventDate.IsZero() {
			return update, ErrVehicleEventDateRequired
		}

		update.EventDate = input.EventDate
	}

	if input.Metadata != nil {
		update.Metadata.Set = true
		update.Metadata.Value = normalizeMetadata(input.Metadata)
	}

	return update, nil
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

func normalizeMetadata(metadata map[string]any) map[string]any {
	if metadata == nil {
		return map[string]any{}
	}

	return metadata
}
