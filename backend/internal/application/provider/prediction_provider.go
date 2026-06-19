package provider

import (
	"context"
	"errors"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

var (
	ErrPredictionProviderUnavailable = errors.New("prediction provider unavailable")
	ErrPredictionProviderTimeout     = errors.New("prediction provider timeout")
)

type PredictionProvider interface {
	Predict(ctx context.Context, input PredictionInput) ([]domain.Prediction, error)
}

type PredictionInput struct {
	Vehicle domain.Vehicle
	Parts   []domain.VehiclePart
	Events  []domain.VehicleEvent
	Catalog []domain.PartCatalogItem
}
