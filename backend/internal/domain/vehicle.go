package domain

import "time"

type Vehicle struct {
	ID           int64     `json:"id"`
	UserID       int64     `json:"user_id"`
	Brand        string    `json:"brand"`
	Model        string    `json:"model"`
	Year         int       `json:"year"`
	VIN          *string   `json:"vin,omitempty"`
	MileageKM    int       `json:"mileage_km"`
	FuelType     *string   `json:"fuel_type,omitempty"`
	Transmission *string   `json:"transmission,omitempty"`
	UsageType    *string   `json:"usage_type,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}
