package domain

import "time"

type PartCatalogItem struct {
	ID                  int64     `json:"id"`
	Code                string    `json:"code"`
	Name                string    `json:"name"`
	Category            string    `json:"category"`
	DefaultLifetimeKM   int       `json:"default_lifetime_km"`
	DefaultLifetimeDays int       `json:"default_lifetime_days"`
	CreatedAt           time.Time `json:"created_at"`
}

type VehiclePart struct {
	ID                   int64      `json:"id"`
	VehicleID            int64      `json:"vehicle_id"`
	CatalogCode          *string    `json:"catalog_code,omitempty"`
	Name                 string     `json:"name"`
	Category             *string    `json:"category,omitempty"`
	InstalledAtMileageKM *int       `json:"installed_at_mileage_km,omitempty"`
	LastServiceMileageKM *int       `json:"last_service_mileage_km,omitempty"`
	LastServiceDate      *time.Time `json:"last_service_date,omitempty"`
	CreatedAt            time.Time  `json:"created_at"`
	UpdatedAt            time.Time  `json:"updated_at"`
}
