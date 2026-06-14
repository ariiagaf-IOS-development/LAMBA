package service

import (
	"context"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

type TimelineService struct {
	events *VehicleEventService
}

func NewTimelineService(events *VehicleEventService) *TimelineService {
	return &TimelineService{events: events}
}

func (s *TimelineService) GetByVehicle(
	ctx context.Context,
	userID int64,
	vehicleID int64,
) ([]domain.VehicleEvent, error) {
	return s.events.List(ctx, userID, vehicleID)
}
