package domain

import "time"

type RiskLevel string

const (
	RiskLevelLow    RiskLevel = "low"
	RiskLevelMedium RiskLevel = "medium"
	RiskLevelHigh   RiskLevel = "high"
)

func (r RiskLevel) IsValid() bool {
	switch r {
	case RiskLevelLow, RiskLevelMedium, RiskLevelHigh:
		return true
	default:
		return false
	}
}

type PredictionSource string

const (
	PredictionSourceRuleBased PredictionSource = "rule_based"
	PredictionSourceMock      PredictionSource = "mock"
	PredictionSourceMLService PredictionSource = "ml_service"
)

type Prediction struct {
	ID                   int64            `json:"id"`
	VehicleID            int64            `json:"vehicle_id"`
	PartCode             *string          `json:"part_code,omitempty"`
	PartName             string           `json:"part_name"`
	PartCategory         *string          `json:"part_category,omitempty"`
	RiskLevel            RiskLevel        `json:"risk_level"`
	RiskScore            *int             `json:"risk_score,omitempty"`
	RemainingKM          *int             `json:"remaining_km,omitempty"`
	RemainingDays        *int             `json:"remaining_days,omitempty"`
	PredictedNextMileage *int             `json:"predicted_next_mileage,omitempty"`
	PredictedNextDate    *time.Time       `json:"predicted_next_date,omitempty"`
	Probability          *float64         `json:"probability,omitempty"`
	Recommendation       string           `json:"recommendation"`
	Explanation          string           `json:"explanation"`
	Source               PredictionSource `json:"source"`
	ModelVersion         *string          `json:"model_version,omitempty"`
	CreatedAt            time.Time        `json:"created_at"`
}
