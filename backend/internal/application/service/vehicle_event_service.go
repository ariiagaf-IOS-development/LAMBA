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
	ErrVehicleEventInvalidType  = errors.New("invalid vehicle event type")
	ErrVehicleEventTitleEmpty   = errors.New("vehicle event title cannot be empty")
	ErrVehicleEventMileage      = errors.New("vehicle event mileage cannot be negative")
	ErrVehicleEventCost         = errors.New("vehicle event cost cannot be negative")
	ErrVehicleEventDateRequired = errors.New("vehicle event date is required")
	ErrVehicleEventLimit        = errors.New("vehicle event limit must be positive")
	ErrVehicleEventOffset       = errors.New("vehicle event offset cannot be negative")
)

const (
	DefaultVehicleEventLimit = 20
	MaxVehicleEventLimit     = 100
)

type VehicleEventService struct {
	events      *repository.VehicleEventRepository
	parts       *repository.PartRepository
	predictions *PredictionService
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

type ListVehicleEventsInput struct {
	Type   *domain.EventType
	Limit  int
	Offset int
}

func NewVehicleEventService(
	events *repository.VehicleEventRepository,
	parts *repository.PartRepository,
	predictions *PredictionService,
) *VehicleEventService {
	return &VehicleEventService{
		events:      events,
		parts:       parts,
		predictions: predictions,
	}
}

func (s *VehicleEventService) Create(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	input CreateVehicleEventInput,
) (domain.VehicleEvent, error) {
	if err := validateVehicleEventType(input.Type); err != nil {
		return domain.VehicleEvent{}, err
	}
	if strings.TrimSpace(input.Title) == "" {
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

	created, err := s.events.CreateForUser(ctx, userID, domain.VehicleEvent{
		VehicleID:   vehicleID,
		Type:        input.Type,
		Title:       strings.TrimSpace(input.Title),
		Description: input.Description,
		MileageKM:   input.MileageKM,
		Cost:        input.Cost,
		EventDate:   input.EventDate,
		Metadata:    input.Metadata,
	})
	if err != nil {
		return domain.VehicleEvent{}, err
	}

	if s.shouldRecalculatePredictions(created.Type) {
		if partCode, ok := affectedPartCode(created.Metadata); ok && s.parts != nil {
			_, _ = s.parts.UpsertServiceByCatalogCodeForUser(
				ctx,
				userID,
				vehicleID,
				partCode,
				created.MileageKM,
				created.EventDate,
			)
		}

		if s.predictions != nil {
			_, _ = s.predictions.RecalculateForVehicle(ctx, userID, vehicleID)
		}
	}

	return created, nil
}

func (s *VehicleEventService) List(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	input ListVehicleEventsInput,
) ([]domain.VehicleEvent, error) {
	filter, err := normalizeVehicleEventFilter(input)
	if err != nil {
		return nil, err
	}

	return s.events.ListByVehicleForUser(ctx, userID, vehicleID, filter)
}

func (s *VehicleEventService) Update(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	eventID int64,
	input UpdateVehicleEventInput,
) (domain.VehicleEvent, error) {
	update := repository.VehicleEventUpdate{}

	if input.Type != nil {
		if err := validateVehicleEventType(*input.Type); err != nil {
			return domain.VehicleEvent{}, err
		}
		update.Type = input.Type
	}

	if input.Title != nil {
		title := strings.TrimSpace(*input.Title)
		if title == "" {
			return domain.VehicleEvent{}, ErrVehicleEventTitleEmpty
		}
		update.Title = &title
	}

	if input.Description != nil {
		update.Description.Set = true
		update.Description.Value = input.Description
	}

	if input.MileageKM != nil {
		if *input.MileageKM < 0 {
			return domain.VehicleEvent{}, ErrVehicleEventMileage
		}
		update.MileageKM = input.MileageKM
	}

	if input.Cost != nil {
		if *input.Cost < 0 {
			return domain.VehicleEvent{}, ErrVehicleEventCost
		}
		update.Cost = input.Cost
	}

	if input.EventDate != nil {
		if input.EventDate.IsZero() {
			return domain.VehicleEvent{}, ErrVehicleEventDateRequired
		}
		update.EventDate = input.EventDate
	}

	if input.Metadata != nil {
		update.Metadata.Set = true
		update.Metadata.Value = input.Metadata
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

func (s *VehicleEventService) Stats(
	ctx context.Context,
	userID int64,
	vehicleID int64,
) (domain.VehicleEventStats, error) {
	return s.events.GetStatsByVehicleForUser(ctx, userID, vehicleID)
}

func normalizeVehicleEventFilter(input ListVehicleEventsInput) (repository.VehicleEventFilter, error) {
	if input.Type != nil {
		if err := validateVehicleEventType(*input.Type); err != nil {
			return repository.VehicleEventFilter{}, err
		}
	}

	limit := input.Limit
	if limit == 0 {
		limit = DefaultVehicleEventLimit
	}
	if limit < 0 {
		return repository.VehicleEventFilter{}, ErrVehicleEventLimit
	}
	if limit > MaxVehicleEventLimit {
		limit = MaxVehicleEventLimit
	}

	if input.Offset < 0 {
		return repository.VehicleEventFilter{}, ErrVehicleEventOffset
	}

	return repository.VehicleEventFilter{
		Type:   input.Type,
		Limit:  limit,
		Offset: input.Offset,
	}, nil
}

func validateVehicleEventType(eventType domain.EventType) error {
	if !eventType.IsValid() {
		return ErrVehicleEventInvalidType
	}

	return nil
}

func (s *VehicleEventService) shouldRecalculatePredictions(eventType domain.EventType) bool {
	switch eventType {
	case domain.EventTypeMaintenance,
		domain.EventTypeRepair,
		domain.EventTypePartReplacement,
		domain.EventTypePrediction:
		return true
	default:
		return false
	}
}

func affectedPartCode(metadata map[string]any) (string, bool) {
	for _, key := range []string{"part_code", "part_category", "part"} {
		value, ok := metadata[key]
		if !ok {
			continue
		}

		partCode, ok := value.(string)
		if ok && strings.TrimSpace(partCode) != "" {
			return strings.TrimSpace(partCode), true
		}
	}

	return "", false
}
