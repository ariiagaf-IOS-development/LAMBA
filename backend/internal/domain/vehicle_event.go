package domain

import "time"

type EventType string

const (
	EventTypeMaintenance     EventType = "maintenance"
	EventTypeRepair          EventType = "repair"
	EventTypeFuel            EventType = "fuel"
	EventTypeDiagnostic      EventType = "diagnostic"
	EventTypePartReplacement EventType = "part_replacement"
	EventTypeNote            EventType = "note"
)

func (t EventType) IsValid() bool {
	switch t {
	case EventTypeMaintenance,
		EventTypeRepair,
		EventTypeFuel,
		EventTypeDiagnostic,
		EventTypePartReplacement,
		EventTypeNote:
		return true
	default:
		return false
	}
}

type VehicleEvent struct {
	ID          int64          `json:"id"`
	VehicleID   int64          `json:"vehicle_id"`
	Type        EventType      `json:"type"`
	Title       string         `json:"title"`
	Description *string        `json:"description,omitempty"`
	MileageKM   int            `json:"mileage_km"`
	Cost        float64        `json:"cost"`
	EventDate   time.Time      `json:"event_date"`
	Metadata    map[string]any `json:"metadata,omitempty"`
	CreatedAt   time.Time      `json:"created_at"`
}

type VehicleEventStats struct {
	TotalEvents int64                    `json:"total_events"`
	TotalCost   float64                  `json:"total_cost"`
	ByType      []VehicleEventTypeStats  `json:"by_type"`
}

type VehicleEventTypeStats struct {
	Type  EventType `json:"type"`
	Count int64     `json:"count"`
	Cost  float64   `json:"cost"`
}