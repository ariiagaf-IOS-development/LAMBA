package service

import (
	"context"
	"fmt"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/application/provider"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
)

const (
	defaultVehicleEventsLimit  = 100
	defaultVehicleEventsOffset = 0
)

type PredictionService struct {
	vehicles    *repository.VehicleRepository
	events      *repository.VehicleEventRepository
	parts       *repository.PartRepository
	predictions *repository.PredictionRepository
	provider    provider.PredictionProvider
}

func NewPredictionService(
	vehicles *repository.VehicleRepository,
	events *repository.VehicleEventRepository,
	parts *repository.PartRepository,
	predictions *repository.PredictionRepository,
	provider provider.PredictionProvider,
) *PredictionService {
	return &PredictionService{
		vehicles:    vehicles,
		events:      events,
		parts:       parts,
		predictions: predictions,
		provider:    provider,
	}
}

func (s *PredictionService) GetOrGenerate(
	ctx context.Context,
	userID int64,
	vehicleID int64,
) ([]domain.Prediction, error) {
	existing, err := s.predictions.ListLatestByVehicleForUser(ctx, userID, vehicleID)
	if err != nil {
		return nil, err
	}

	if len(existing) > 0 {
		return existing, nil
	}

	return s.Recalculate(ctx, userID, vehicleID)
}

func (s *PredictionService) Recalculate(
	ctx context.Context,
	userID int64,
	vehicleID int64,
) ([]domain.Prediction, error) {
	vehicle, err := s.vehicles.GetByIDForUser(ctx, userID, vehicleID)
	if err != nil {
		return nil, err
	}

	events, err := s.events.ListByVehicleForUser(ctx, userID, vehicleID, repository.VehicleEventFilter{
		Limit:  defaultVehicleEventsLimit,
		Offset: defaultVehicleEventsOffset,
	})
	if err != nil {
		return nil, err
	}

	parts, err := s.parts.ListByVehicleForUser(ctx, userID, vehicleID)
	if err != nil {
		return nil, err
	}

	catalog, err := s.parts.ListCatalog(ctx)
	if err != nil {
		return nil, err
	}

	generated, err := s.provider.Predict(ctx, provider.PredictionInput{
		Vehicle: vehicle,
		Events:  events,
		Parts:   parts,
		Catalog: catalog,
	})
	if err != nil {
		return nil, fmt.Errorf("generate predictions: %w", err)
	}

	return s.predictions.ReplaceForVehicleForUser(ctx, userID, vehicleID, generated)
}

func (s *PredictionService) RecalculateForVehicle(
	ctx context.Context,
	userID int64,
	vehicleID int64,
) ([]domain.Prediction, error) {
	return s.Recalculate(ctx, userID, vehicleID)
}
