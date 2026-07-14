package service

import (
	"context"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
)

const (
	dashboardLatestEventsLimit = 5

	riskPriorityHigh   = 3
	riskPriorityMedium = 2
	riskPriorityLow    = 1
	riskPriorityNone   = 0
)

type DashboardService struct {
	vehicles    *repository.VehicleRepository
	events      *repository.VehicleEventRepository
	predictions *repository.PredictionRepository
}

func NewDashboardService(
	vehicles *repository.VehicleRepository,
	events *repository.VehicleEventRepository,
	predictions *repository.PredictionRepository,
) *DashboardService {
	return &DashboardService{
		vehicles:    vehicles,
		events:      events,
		predictions: predictions,
	}
}

func (s *DashboardService) Get(
	ctx context.Context,
	userID int64,
	vehicleID int64,
) (domain.VehicleDashboard, error) {
	vehicle, err := s.vehicles.GetByIDForUser(ctx, userID, vehicleID)
	if err != nil {
		return domain.VehicleDashboard{}, err
	}

	stats, err := s.events.GetDashboardStatsByVehicleForUser(ctx, userID, vehicleID)
	if err != nil {
		return domain.VehicleDashboard{}, err
	}

	latestEvents, err := s.events.ListByVehicleForUser(ctx, userID, vehicleID, repository.VehicleEventFilter{
		Limit:  dashboardLatestEventsLimit,
		Offset: 0,
	})
	if err != nil {
		return domain.VehicleDashboard{}, err
	}

	predictions, err := s.predictions.ListLatestByVehicleForUser(ctx, userID, vehicleID)
	if err != nil {
		return domain.VehicleDashboard{}, err
	}

	var predictionSummary *domain.DashboardPredictionSummary
	if len(predictions) > 0 {
		selected := selectMostImportantPrediction(predictions)
		predictionSummary = &domain.DashboardPredictionSummary{
			PartName:       selected.PartName,
			PartCategory:   selected.PartCategory,
			RiskLevel:      selected.RiskLevel,
			RiskScore:      selected.RiskScore,
			RemainingKM:    selected.RemainingKM,
			RemainingDays:  selected.RemainingDays,
			Probability:    selected.Probability,
			Recommendation: selected.Recommendation,
			ModelVersion:   selected.ModelVersion,
			CreatedAt:      selected.CreatedAt,
		}
	}

	return domain.VehicleDashboard{
		Vehicle: domain.DashboardVehicleSummary{
			ID:        vehicle.ID,
			Brand:     vehicle.Brand,
			Model:     vehicle.Model,
			Year:      vehicle.Year,
			VIN:       vehicle.VIN,
			MileageKM: vehicle.MileageKM,
		},
		CurrentMileage:       vehicle.MileageKM,
		TotalMaintenanceCost: stats.TotalMaintenanceCost,
		TotalFuelExpenses:    stats.TotalFuelExpenses,
		TotalRepairsCount:    stats.TotalRepairsCount,
		TotalEventsCount:     stats.TotalEventsCount,
		LatestEvents:         toDashboardEventPreviews(latestEvents),
		PredictionSummary:    predictionSummary,
		AllPredictions:       predictions,
		Status:               computeVehicleStatus(predictions),
	}, nil
}

func computeVehicleStatus(predictions []domain.Prediction) string {
	if len(predictions) == 0 {
		return "unknown"
	}

	maxPriority := riskPriorityNone
	for _, p := range predictions {
		if pri := riskPriority(p.RiskLevel); pri > maxPriority {
			maxPriority = pri
		}
	}

	switch maxPriority {
	case riskPriorityHigh:
		return "warning"
	case riskPriorityMedium:
		return "attention"
	default:
		return "good"
	}
}

func toDashboardEventPreviews(events []domain.VehicleEvent) []domain.DashboardEventPreview {
	previews := make([]domain.DashboardEventPreview, 0, len(events))

	for _, event := range events {
		previews = append(previews, domain.DashboardEventPreview{
			ID:        event.ID,
			Type:      event.Type,
			Title:     event.Title,
			MileageKM: event.MileageKM,
			Cost:      event.Cost,
			EventDate: event.EventDate,
		})
	}

	return previews
}

func selectMostImportantPrediction(predictions []domain.Prediction) domain.Prediction {
	selected := predictions[0]

	for _, prediction := range predictions[1:] {
		if riskPriority(prediction.RiskLevel) > riskPriority(selected.RiskLevel) {
			selected = prediction
			continue
		}

		if riskPriority(prediction.RiskLevel) == riskPriority(selected.RiskLevel) &&
			prediction.CreatedAt.After(selected.CreatedAt) {
			selected = prediction
		}
	}

	return selected
}

func riskPriority(level domain.RiskLevel) int {
	switch level {
	case domain.RiskLevelHigh:
		return riskPriorityHigh
	case domain.RiskLevelMedium:
		return riskPriorityMedium
	case domain.RiskLevelLow:
		return riskPriorityLow
	default:
		return riskPriorityNone
	}
}
