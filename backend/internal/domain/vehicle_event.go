package domain

import "time"

type EventType string

const (
	EventTypeTrip    EventType = "trip"
	EventTypeRefuel  EventType = "refuel"
	EventTypeRepair  EventType = "repair"
	EventTypeService EventType = "service"
)

type VehicleEvent struct {
	ID          int64     `json:"id"`
	VehicleID   int64     `json:"vehicle_id"`
	Type        EventType `json:"type"`
	Title       string    `json:"title"`
	Description *string   `json:"description,omitempty"`
	MileageKM   int       `json:"mileage_km"`
	Cost        float64   `json:"cost"`
	EventDate   time.Time `json:"event_date"`
	CreatedAt   time.Time `json:"created_at"`
}
