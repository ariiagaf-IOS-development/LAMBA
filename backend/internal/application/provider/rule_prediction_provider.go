package provider

import (
	"context"
	"fmt"
	"math"
	"time"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

const (
	defaultAverageDailyMileage = 30

	mediumRiskUsageRatio = 0.75
	highRiskUsageRatio   = 0.95
)

type RuleBasedPredictionProvider struct {
	now func() time.Time
}

func NewRuleBasedPredictionProvider() *RuleBasedPredictionProvider {
	return &RuleBasedPredictionProvider{
		now: time.Now,
	}
}

func (p *RuleBasedPredictionProvider) Predict(
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

	catalogByCode := make(map[string]domain.PartCatalogItem, len(input.Catalog))
	for _, item := range input.Catalog {
		catalogByCode[item.Code] = item
	}

	predictions := make([]domain.Prediction, 0, len(input.Parts))
	now := p.now()

	for _, part := range input.Parts {
		catalogItem, ok := catalogItemForPart(part, catalogByCode)
		if !ok {
			continue
		}

		lastMileage := lastKnownServiceMileage(part, input.Vehicle.MileageKM)
		usedMileage := input.Vehicle.MileageKM - lastMileage
		if usedMileage < 0 {
			usedMileage = 0
		}

		remainingKM := catalogItem.DefaultLifetimeKM - usedMileage
		if remainingKM < 0 {
			remainingKM = 0
		}

		remainingDays := estimateRemainingDays(part, catalogItem, now, usedMileage, remainingKM)

		usageRatio := float64(usedMileage) / float64(catalogItem.DefaultLifetimeKM)
		riskLevel := riskLevelFromUsageRatio(usageRatio)
		riskScore := riskScoreFromUsageRatio(usageRatio)

		predictedNextMileage := input.Vehicle.MileageKM + remainingKM
		predictedNextDate := now.AddDate(0, 0, remainingDays)
		probability := float64(riskScore) / 100

		predictions = append(predictions, domain.Prediction{
			VehicleID:            input.Vehicle.ID,
			PartCode:             part.CatalogCode,
			PartName:             part.Name,
			PartCategory:         part.Category,
			RiskLevel:            riskLevel,
			RiskScore:            &riskScore,
			RemainingKM:          &remainingKM,
			RemainingDays:        &remainingDays,
			PredictedNextMileage: &predictedNextMileage,
			PredictedNextDate:    &predictedNextDate,
			Probability:          &probability,
			Recommendation:       recommendationForRisk(part.Name, riskLevel),
			Explanation:          explanationForPart(part.Name, usedMileage, catalogItem.DefaultLifetimeKM, remainingKM),
			Source:               domain.PredictionSourceRuleBased,
		})
	}

	return predictions, nil
}

func catalogItemForPart(
	part domain.VehiclePart,
	catalogByCode map[string]domain.PartCatalogItem,
) (domain.PartCatalogItem, bool) {
	if part.CatalogCode == nil {
		return domain.PartCatalogItem{}, false
	}

	item, ok := catalogByCode[*part.CatalogCode]
	return item, ok
}

func lastKnownServiceMileage(part domain.VehiclePart, currentMileage int) int {
	if part.LastServiceMileageKM != nil {
		return *part.LastServiceMileageKM
	}

	if part.InstalledAtMileageKM != nil {
		return *part.InstalledAtMileageKM
	}

	return currentMileage
}

func estimateRemainingDays(
	part domain.VehiclePart,
	catalogItem domain.PartCatalogItem,
	now time.Time,
	usedMileage int,
	remainingKM int,
) int {
	daysByMileage := int(math.Ceil(float64(remainingKM) / defaultAverageDailyMileage))

	if part.LastServiceDate == nil {
		return minInt(daysByMileage, catalogItem.DefaultLifetimeDays)
	}

	daysSinceService := int(now.Sub(*part.LastServiceDate).Hours() / 24)
	if daysSinceService < 0 {
		daysSinceService = 0
	}

	daysByTime := catalogItem.DefaultLifetimeDays - daysSinceService
	if daysByTime < 0 {
		daysByTime = 0
	}

	return minInt(daysByMileage, daysByTime)
}

func riskLevelFromUsageRatio(ratio float64) domain.RiskLevel {
	switch {
	case ratio >= highRiskUsageRatio:
		return domain.RiskLevelHigh
	case ratio >= mediumRiskUsageRatio:
		return domain.RiskLevelMedium
	default:
		return domain.RiskLevelLow
	}
}

func riskScoreFromUsageRatio(ratio float64) int {
	score := int(math.Round(ratio * 100))
	if score < 0 {
		return 0
	}
	if score > 100 {
		return 100
	}

	return score
}

func recommendationForRisk(partName string, riskLevel domain.RiskLevel) string {
	switch riskLevel {
	case domain.RiskLevelHigh:
		return fmt.Sprintf("%s requires maintenance as soon as possible.", partName)
	case domain.RiskLevelMedium:
		return fmt.Sprintf("%s should be checked soon.", partName)
	default:
		return fmt.Sprintf("%s is in good condition.", partName)
	}
}

func explanationForPart(
	partName string,
	usedMileage int,
	lifetimeKM int,
	remainingKM int,
) string {
	return fmt.Sprintf(
		"%d km have passed since the last service for %s. Expected lifetime is %d km, remaining mileage is %d km.",
		usedMileage,
		partName,
		lifetimeKM,
		remainingKM,
	)
}

func minInt(a int, b int) int {
	if a < b {
		return a
	}

	return b
}
