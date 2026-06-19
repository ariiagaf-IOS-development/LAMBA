package provider

import (
	"context"
	"fmt"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

type MockPredictionProvider struct{}

func NewMockPredictionProvider() *MockPredictionProvider {
	return &MockPredictionProvider{}
}

func (p *MockPredictionProvider) Predict(
	ctx context.Context,
	input PredictionInput,
) ([]domain.Prediction, error) {
	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	default:
	}

	if len(input.Parts) == 0 {
		return []domain.Prediction{}, nil
	}

	predictions := make([]domain.Prediction, 0, len(input.Parts))

	for _, part := range input.Parts {
		partName := part.Name
		partCode := part.CatalogCode
		partCategory := part.Category

		riskScore := 35
		remainingKM := 7000
		remainingDays := 180
		predictedNextMileage := input.Vehicle.MileageKM + remainingKM
		probability := 0.35

		predictions = append(predictions, domain.Prediction{
			VehicleID:            input.Vehicle.ID,
			PartCode:             partCode,
			PartName:             partName,
			PartCategory:         partCategory,
			RiskLevel:            domain.RiskLevelLow,
			RiskScore:            &riskScore,
			RemainingKM:          &remainingKM,
			RemainingDays:        &remainingDays,
			PredictedNextMileage: &predictedNextMileage,
			Probability:          &probability,
			Recommendation:       fmt.Sprintf("%s is in stable condition.", partName),
			Explanation:          "Mock prediction generated for integration testing.",
			Source:               domain.PredictionSourceMock,
		})
	}

	return predictions, nil
}
