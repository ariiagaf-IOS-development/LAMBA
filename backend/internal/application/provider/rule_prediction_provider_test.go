package provider

import (
	"context"
	"testing"
	"time"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

func TestRuleBasedPredictionProvider_NoParts(t *testing.T) {
	p := NewRuleBasedPredictionProvider()
	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(predictions) != 0 {
		t.Fatalf("expected 0 predictions, got %d", len(predictions))
	}
}

func TestRuleBasedPredictionProvider_NoCatalogCode(t *testing.T) {
	p := NewRuleBasedPredictionProvider()
	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
		Parts:   []domain.VehiclePart{{ID: 1, Name: "Oil"}},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(predictions) != 0 {
		t.Fatalf("expected 0 predictions for part without catalog code, got %d", len(predictions))
	}
}

func TestRuleBasedPredictionProvider_PartNotInCatalog(t *testing.T) {
	p := NewRuleBasedPredictionProvider()
	code := "missing_code"
	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
		Parts:   []domain.VehiclePart{{ID: 1, Name: "Oil", CatalogCode: &code}},
		Catalog: []domain.PartCatalogItem{{Code: "other_code", DefaultLifetimeKM: 10000, DefaultLifetimeDays: 365}},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(predictions) != 0 {
		t.Fatalf("expected 0 predictions for part not in catalog, got %d", len(predictions))
	}
}

func TestRuleBasedPredictionProvider_LowRisk(t *testing.T) {
	now := time.Now()
	p := &RuleBasedPredictionProvider{now: func() time.Time { return now }}
	code := "engine_oil"
	lastMileage := 45000

	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
		Parts: []domain.VehiclePart{{
			ID:                   1,
			VehicleID:            1,
			Name:                 "Engine Oil",
			CatalogCode:          &code,
			LastServiceMileageKM: &lastMileage,
		}},
		Catalog: []domain.PartCatalogItem{{
			Code:                "engine_oil",
			DefaultLifetimeKM:   10000,
			DefaultLifetimeDays: 365,
		}},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(predictions) != 1 {
		t.Fatalf("expected 1 prediction, got %d", len(predictions))
	}

	pred := predictions[0]
	if pred.RiskLevel != domain.RiskLevelLow {
		t.Fatalf("expected low risk (used 5000/10000 = 0.5), got %s", pred.RiskLevel)
	}
	if pred.Source != domain.PredictionSourceRuleBased {
		t.Fatalf("expected rule_based source, got %s", pred.Source)
	}
	if pred.VehicleID != 1 {
		t.Fatalf("expected vehicle ID 1, got %d", pred.VehicleID)
	}
	if pred.PartName != "Engine Oil" {
		t.Fatalf("expected part name Engine Oil, got %s", pred.PartName)
	}
}

func TestRuleBasedPredictionProvider_MediumRisk(t *testing.T) {
	now := time.Now()
	p := &RuleBasedPredictionProvider{now: func() time.Time { return now }}
	code := "engine_oil"
	lastMileage := 42000

	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
		Parts: []domain.VehiclePart{{
			ID:                   1,
			VehicleID:            1,
			Name:                 "Engine Oil",
			CatalogCode:          &code,
			LastServiceMileageKM: &lastMileage,
		}},
		Catalog: []domain.PartCatalogItem{{
			Code:                "engine_oil",
			DefaultLifetimeKM:   10000,
			DefaultLifetimeDays: 365,
		}},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(predictions) != 1 {
		t.Fatalf("expected 1 prediction, got %d", len(predictions))
	}
	if predictions[0].RiskLevel != domain.RiskLevelMedium {
		t.Fatalf("expected medium risk (used 8000/10000 = 0.8), got %s", predictions[0].RiskLevel)
	}
}

func TestRuleBasedPredictionProvider_HighRisk(t *testing.T) {
	now := time.Now()
	p := &RuleBasedPredictionProvider{now: func() time.Time { return now }}
	code := "engine_oil"
	lastMileage := 40500

	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
		Parts: []domain.VehiclePart{{
			ID:                   1,
			VehicleID:            1,
			Name:                 "Engine Oil",
			CatalogCode:          &code,
			LastServiceMileageKM: &lastMileage,
		}},
		Catalog: []domain.PartCatalogItem{{
			Code:                "engine_oil",
			DefaultLifetimeKM:   10000,
			DefaultLifetimeDays: 365,
		}},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if predictions[0].RiskLevel != domain.RiskLevelHigh {
		t.Fatalf("expected high risk (used 9500/10000 = 0.95), got %s", predictions[0].RiskLevel)
	}
}

func TestRuleBasedPredictionProvider_OverdueRemainingKM(t *testing.T) {
	now := time.Now()
	p := &RuleBasedPredictionProvider{now: func() time.Time { return now }}
	code := "engine_oil"
	lastMileage := 35000

	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
		Parts: []domain.VehiclePart{{
			ID:                   1,
			VehicleID:            1,
			Name:                 "Engine Oil",
			CatalogCode:          &code,
			LastServiceMileageKM: &lastMileage,
		}},
		Catalog: []domain.PartCatalogItem{{
			Code:                "engine_oil",
			DefaultLifetimeKM:   10000,
			DefaultLifetimeDays: 365,
		}},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if predictions[0].RemainingKM == nil || *predictions[0].RemainingKM != 0 {
		t.Fatalf("expected remainingKM = 0 (overdue), got %v", predictions[0].RemainingKM)
	}
}

func TestRuleBasedPredictionProvider_InstalledAtMileageUsed(t *testing.T) {
	now := time.Now()
	p := &RuleBasedPredictionProvider{now: func() time.Time { return now }}
	code := "engine_oil"
	installed := 48000

	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
		Parts: []domain.VehiclePart{{
			ID:                   1,
			VehicleID:            1,
			Name:                 "Engine Oil",
			CatalogCode:          &code,
			InstalledAtMileageKM: &installed,
		}},
		Catalog: []domain.PartCatalogItem{{
			Code:                "engine_oil",
			DefaultLifetimeKM:   10000,
			DefaultLifetimeDays: 365,
		}},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if predictions[0].RiskLevel != domain.RiskLevelLow {
		t.Fatalf("expected low risk (used 2000/10000 = 0.2), got %s", predictions[0].RiskLevel)
	}
}

func TestRuleBasedPredictionProvider_NoServiceInfo(t *testing.T) {
	now := time.Now()
	p := &RuleBasedPredictionProvider{now: func() time.Time { return now }}
	code := "engine_oil"

	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
		Parts: []domain.VehiclePart{{
			ID:          1,
			VehicleID:   1,
			Name:        "Engine Oil",
			CatalogCode: &code,
		}},
		Catalog: []domain.PartCatalogItem{{
			Code:                "engine_oil",
			DefaultLifetimeKM:   10000,
			DefaultLifetimeDays: 365,
		}},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(predictions) != 1 {
		t.Fatalf("expected 1 prediction, got %d", len(predictions))
	}
	if predictions[0].RemainingKM == nil || *predictions[0].RemainingKM != 10000 {
		t.Fatalf("expected remainingKM 10000, got %v", predictions[0].RemainingKM)
	}
}

func TestRuleBasedPredictionProvider_WithLastServiceDate(t *testing.T) {
	now := time.Now()
	p := &RuleBasedPredictionProvider{now: func() time.Time { return now }}
	code := "engine_oil"
	lastMileage := 49000
	lastDate := now.Add(-30 * 24 * time.Hour)

	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
		Parts: []domain.VehiclePart{{
			ID:                   1,
			VehicleID:            1,
			Name:                 "Engine Oil",
			CatalogCode:          &code,
			LastServiceMileageKM: &lastMileage,
			LastServiceDate:      &lastDate,
		}},
		Catalog: []domain.PartCatalogItem{{
			Code:                "engine_oil",
			DefaultLifetimeKM:   10000,
			DefaultLifetimeDays: 365,
		}},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(predictions) != 1 {
		t.Fatalf("expected 1 prediction, got %d", len(predictions))
	}
	if predictions[0].RemainingDays == nil {
		t.Fatal("expected non-nil remaining days")
	}
}

func TestRuleBasedPredictionProvider_CanceledContext(t *testing.T) {
	p := NewRuleBasedPredictionProvider()
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err := p.Predict(ctx, PredictionInput{})
	if err == nil {
		t.Fatal("expected error for canceled context")
	}
}

func TestRuleBasedPredictionProvider_MultipleParts(t *testing.T) {
	now := time.Now()
	p := &RuleBasedPredictionProvider{now: func() time.Time { return now }}
	oilCode := "engine_oil"
	brakesCode := "brake_pads"
	lastMileage := 45000

	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
		Parts: []domain.VehiclePart{
			{ID: 1, Name: "Engine Oil", CatalogCode: &oilCode, LastServiceMileageKM: &lastMileage},
			{ID: 2, Name: "Brake Pads", CatalogCode: &brakesCode, LastServiceMileageKM: &lastMileage},
		},
		Catalog: []domain.PartCatalogItem{
			{Code: "engine_oil", DefaultLifetimeKM: 10000, DefaultLifetimeDays: 365},
			{Code: "brake_pads", DefaultLifetimeKM: 30000, DefaultLifetimeDays: 730},
		},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(predictions) != 2 {
		t.Fatalf("expected 2 predictions, got %d", len(predictions))
	}
}

func TestRiskLevelFromUsageRatio(t *testing.T) {
	tests := []struct {
		ratio float64
		want  domain.RiskLevel
	}{
		{0.0, domain.RiskLevelLow},
		{0.5, domain.RiskLevelLow},
		{0.74, domain.RiskLevelLow},
		{0.75, domain.RiskLevelMedium},
		{0.85, domain.RiskLevelMedium},
		{0.94, domain.RiskLevelMedium},
		{0.95, domain.RiskLevelHigh},
		{1.0, domain.RiskLevelHigh},
		{1.5, domain.RiskLevelHigh},
	}

	for _, tt := range tests {
		got := riskLevelFromUsageRatio(tt.ratio)
		if got != tt.want {
			t.Errorf("riskLevelFromUsageRatio(%f): expected %s, got %s", tt.ratio, tt.want, got)
		}
	}
}

func TestRiskScoreFromUsageRatio(t *testing.T) {
	tests := []struct {
		ratio float64
		want  int
	}{
		{0.0, 0},
		{0.5, 50},
		{1.0, 100},
		{1.5, 100},
	}

	for _, tt := range tests {
		got := riskScoreFromUsageRatio(tt.ratio)
		if got != tt.want {
			t.Errorf("riskScoreFromUsageRatio(%f): expected %d, got %d", tt.ratio, tt.want, got)
		}
	}
}

func TestRecommendationForRisk(t *testing.T) {
	tests := []struct {
		level    domain.RiskLevel
		contains string
	}{
		{domain.RiskLevelHigh, "as soon as possible"},
		{domain.RiskLevelMedium, "checked soon"},
		{domain.RiskLevelLow, "good condition"},
	}

	for _, tt := range tests {
		got := recommendationForRisk("Brakes", tt.level)
		if got == "" {
			t.Fatalf("expected non-empty recommendation for %s", tt.level)
		}
	}
}

func TestExplanationForPart(t *testing.T) {
	explanation := explanationForPart("Engine Oil", 5000, 10000, 5000)
	if explanation == "" {
		t.Fatal("expected non-empty explanation")
	}
}

func TestMinInt(t *testing.T) {
	if minInt(1, 2) != 1 {
		t.Fatal("expected 1")
	}
	if minInt(2, 1) != 1 {
		t.Fatal("expected 1")
	}
	if minInt(3, 3) != 3 {
		t.Fatal("expected 3")
	}
}
