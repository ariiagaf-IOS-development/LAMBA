package provider

import (
	"context"
	"testing"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

func TestMockPredictionProvider_NoParts(t *testing.T) {
	p := NewMockPredictionProvider()
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

func TestMockPredictionProvider_WithParts(t *testing.T) {
	p := NewMockPredictionProvider()
	code := "engine_oil"
	category := "fluids"

	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
		Parts: []domain.VehiclePart{
			{ID: 1, Name: "Engine Oil", CatalogCode: &code, Category: &category},
			{ID: 2, Name: "Brake Pads"},
		},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(predictions) != 2 {
		t.Fatalf("expected 2 predictions, got %d", len(predictions))
	}

	for _, pred := range predictions {
		if pred.VehicleID != 1 {
			t.Fatalf("expected vehicle ID 1, got %d", pred.VehicleID)
		}
		if pred.RiskLevel != domain.RiskLevelLow {
			t.Fatalf("expected low risk, got %s", pred.RiskLevel)
		}
		if pred.Source != domain.PredictionSourceMock {
			t.Fatalf("expected mock source, got %s", pred.Source)
		}
		if pred.RiskScore == nil || *pred.RiskScore != 35 {
			t.Fatalf("expected risk score 35, got %v", pred.RiskScore)
		}
	}

	if predictions[0].PartName != "Engine Oil" {
		t.Fatalf("expected part name Engine Oil, got %s", predictions[0].PartName)
	}
	if predictions[0].PartCode == nil || *predictions[0].PartCode != "engine_oil" {
		t.Fatalf("expected part code engine_oil, got %v", predictions[0].PartCode)
	}
}

func TestMockPredictionProvider_CanceledContext(t *testing.T) {
	p := NewMockPredictionProvider()
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err := p.Predict(ctx, PredictionInput{
		Vehicle: domain.Vehicle{ID: 1},
		Parts:   []domain.VehiclePart{{ID: 1, Name: "Oil"}},
	})
	if err == nil {
		t.Fatal("expected error for canceled context")
	}
}
