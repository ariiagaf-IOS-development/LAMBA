package domain

import "time"

type User struct {
	ID           int64     `json:"id"`
	Email        string    `json:"email"`
	PasswordHash string    `json:"-"`
	CreatedAt    time.Time `json:"created_at"`
}

type Vehicle struct {
	ID        int64     `json:"id"`
	UserID    int64     `json:"user_id"`
	Brand     string    `json:"brand"`
	Model     string    `json:"model"`
	Year      int       `json:"year"`
	VIN       *string   `json:"vin,omitempty"`
	MileageKM int       `json:"mileage_km"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
