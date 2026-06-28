package service

import (
	"context"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
)

type PartService struct {
	parts *repository.PartRepository
}

func NewPartService(parts *repository.PartRepository) *PartService {
	return &PartService{parts: parts}
}

func (s *PartService) ListCatalog(ctx context.Context) ([]domain.PartCatalogItem, error) {
	return s.parts.ListCatalog(ctx)
}

func (s *PartService) ListByVehicle(
	ctx context.Context,
	userID int64,
	vehicleID int64,
) ([]domain.VehiclePart, error) {
	return s.parts.ListByVehicleForUser(ctx, userID, vehicleID)
}

func (s *PartService) Create(
	ctx context.Context,
	userID int64,
	input repository.CreateVehiclePartInput,
) (domain.VehiclePart, error) {
	return s.parts.CreateForUser(ctx, userID, input)
}

func (s *PartService) Delete(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	partID int64,
) error {
	return s.parts.DeleteForUser(ctx, userID, vehicleID, partID)
}
