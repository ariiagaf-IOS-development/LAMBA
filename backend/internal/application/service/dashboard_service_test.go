package service

import (
	"testing"
	"time"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

func TestComputeVehicleStatus(t *testing.T) {
	tests := []struct {
		name        string
		predictions []domain.Prediction
		want        string
	}{
		{"no predictions", nil, "unknown"},
		{"empty predictions", []domain.Prediction{}, "unknown"},
		{
			"all low risk",
			[]domain.Prediction{
				{RiskLevel: domain.RiskLevelLow},
				{RiskLevel: domain.RiskLevelLow},
			},
			"good",
		},
		{
			"medium risk",
			[]domain.Prediction{
				{RiskLevel: domain.RiskLevelLow},
				{RiskLevel: domain.RiskLevelMedium},
			},
			"attention",
		},
		{
			"high risk",
			[]domain.Prediction{
				{RiskLevel: domain.RiskLevelLow},
				{RiskLevel: domain.RiskLevelHigh},
			},
			"warning",
		},
		{
			"high overrides medium",
			[]domain.Prediction{
				{RiskLevel: domain.RiskLevelMedium},
				{RiskLevel: domain.RiskLevelHigh},
			},
			"warning",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := computeVehicleStatus(tt.predictions)
			if got != tt.want {
				t.Fatalf("expected %q, got %q", tt.want, got)
			}
		})
	}
}

func TestRiskPriority(t *testing.T) {
	tests := []struct {
		level    domain.RiskLevel
		expected int
	}{
		{domain.RiskLevelHigh, riskPriorityHigh},
		{domain.RiskLevelMedium, riskPriorityMedium},
		{domain.RiskLevelLow, riskPriorityLow},
		{domain.RiskLevel("unknown"), riskPriorityNone},
	}

	for _, tt := range tests {
		got := riskPriority(tt.level)
		if got != tt.expected {
			t.Fatalf("riskPriority(%q): expected %d, got %d", tt.level, tt.expected, got)
		}
	}
}

func TestSelectMostImportantPrediction(t *testing.T) {
	now := time.Now()
	older := now.Add(-time.Hour)

	tests := []struct {
		name        string
		predictions []domain.Prediction
		wantName    string
	}{
		{
			"single prediction",
			[]domain.Prediction{{PartName: "Oil", RiskLevel: domain.RiskLevelLow, CreatedAt: now}},
			"Oil",
		},
		{
			"high risk wins over low",
			[]domain.Prediction{
				{PartName: "Oil", RiskLevel: domain.RiskLevelLow, CreatedAt: now},
				{PartName: "Brakes", RiskLevel: domain.RiskLevelHigh, CreatedAt: older},
			},
			"Brakes",
		},
		{
			"same risk, newer wins",
			[]domain.Prediction{
				{PartName: "Oil", RiskLevel: domain.RiskLevelMedium, CreatedAt: older},
				{PartName: "Tires", RiskLevel: domain.RiskLevelMedium, CreatedAt: now},
			},
			"Tires",
		},
		{
			"high risk always wins",
			[]domain.Prediction{
				{PartName: "Oil", RiskLevel: domain.RiskLevelMedium, CreatedAt: now},
				{PartName: "Brakes", RiskLevel: domain.RiskLevelHigh, CreatedAt: older},
				{PartName: "Tires", RiskLevel: domain.RiskLevelLow, CreatedAt: now},
			},
			"Brakes",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := selectMostImportantPrediction(tt.predictions)
			if got.PartName != tt.wantName {
				t.Fatalf("expected %q, got %q", tt.wantName, got.PartName)
			}
		})
	}
}

func TestToDashboardEventPreviews(t *testing.T) {
	now := time.Now()
	events := []domain.VehicleEvent{
		{ID: 1, Type: domain.EventTypeRepair, Title: "Repair", MileageKM: 100, Cost: 500, EventDate: now},
		{ID: 2, Type: domain.EventTypeRefuel, Title: "Refuel", MileageKM: 200, Cost: 300, EventDate: now},
	}

	previews := toDashboardEventPreviews(events)
	if len(previews) != 2 {
		t.Fatalf("expected 2 previews, got %d", len(previews))
	}
	if previews[0].ID != 1 {
		t.Fatalf("expected first preview ID 1, got %d", previews[0].ID)
	}
	if previews[1].Title != "Refuel" {
		t.Fatalf("expected second preview title Refuel, got %s", previews[1].Title)
	}
}

func TestToDashboardEventPreviews_Empty(t *testing.T) {
	previews := toDashboardEventPreviews(nil)
	if len(previews) != 0 {
		t.Fatalf("expected 0 previews, got %d", len(previews))
	}
}
