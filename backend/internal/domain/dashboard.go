package domain

import "time"

type VehicleDashboard struct {
	Vehicle              DashboardVehicleSummary     `json:"vehicle"`
	CurrentMileage       int                         `json:"current_mileage"`
	TotalMaintenanceCost float64                     `json:"total_maintenance_cost"`
	TotalFuelExpenses    float64                     `json:"total_fuel_expenses"`
	TotalRepairsCount    int64                       `json:"total_repairs_count"`
	TotalEventsCount     int64                       `json:"total_events_count"`
	LatestEvents         []DashboardEventPreview     `json:"latest_events"`
	PredictionSummary    *DashboardPredictionSummary `json:"prediction_summary,omitempty"`
}

type DashboardVehicleSummary struct {
	ID        int64   `json:"id"`
	Brand     string  `json:"brand"`
	Model     string  `json:"model"`
	Year      int     `json:"year"`
	VIN       *string `json:"vin,omitempty"`
	MileageKM int     `json:"mileage_km"`
}

type DashboardEventPreview struct {
	ID        int64     `json:"id"`
	Type      EventType `json:"type"`
	Title     string    `json:"title"`
	MileageKM int       `json:"mileage_km"`
	Cost      float64   `json:"cost"`
	EventDate time.Time `json:"event_date"`
}

type DashboardPredictionSummary struct {
	PartName       string    `json:"part_name"`
	PartCategory   *string   `json:"part_category,omitempty"`
	RiskLevel      RiskLevel `json:"risk_level"`
	RiskScore      *int      `json:"risk_score,omitempty"`
	RemainingKM    *int      `json:"remaining_km,omitempty"`
	RemainingDays  *int      `json:"remaining_days,omitempty"`
	Probability    *float64  `json:"probability,omitempty"`
	Recommendation string    `json:"recommendation"`
	ModelVersion   *string   `json:"model_version,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
}

type DashboardEventStats struct {
	TotalMaintenanceCost float64
	TotalFuelExpenses    float64
	TotalRepairsCount    int64
	TotalEventsCount     int64
}
