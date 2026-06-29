package service

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/application/provider"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
)

type ToolDispatcher struct {
	vehicles    *repository.VehicleRepository
	events      *repository.VehicleEventRepository
	parts       *repository.PartRepository
	predictions *PredictionService
}

type ToolContext struct {
	UserID    int64
	VehicleID int64
}

func NewToolDispatcher(
	vehicles *repository.VehicleRepository,
	events *repository.VehicleEventRepository,
	parts *repository.PartRepository,
	predictions *PredictionService,
) *ToolDispatcher {
	return &ToolDispatcher{
		vehicles:    vehicles,
		events:      events,
		parts:       parts,
		predictions: predictions,
	}
}

func (d *ToolDispatcher) Dispatch(
	ctx context.Context,
	toolCtx ToolContext,
	name string,
	argsJSON string,
) (string, error) {
	switch name {
	case "get_vehicle_profile":
		return d.getVehicleProfile(ctx, toolCtx)
	case "list_vehicle_events":
		return d.listVehicleEvents(ctx, toolCtx, argsJSON)
	case "create_vehicle_event":
		return d.createVehicleEvent(ctx, toolCtx, argsJSON)
	case "update_vehicle_mileage":
		return d.updateVehicleMileage(ctx, toolCtx, argsJSON)
	case "get_predictions":
		return d.getPredictions(ctx, toolCtx)
	default:
		return "", fmt.Errorf("unknown tool: %s", name)
	}
}

func (d *ToolDispatcher) ToolDefinitions() []provider.AIToolDefinition {
	return []provider.AIToolDefinition{
		{
			Type: "function",
			Function: provider.AIFunctionSchema{
				Name:        "get_vehicle_profile",
				Description: "Get the current vehicle's profile including brand, model, year, mileage, VIN, fuel type, transmission, and usage type",
				Parameters: map[string]any{
					"type":       "object",
					"properties": map[string]any{},
				},
			},
		},
		{
			Type: "function",
			Function: provider.AIFunctionSchema{
				Name:        "list_vehicle_events",
				Description: "List maintenance events, repairs, trips, and other events for the current vehicle",
				Parameters: map[string]any{
					"type": "object",
					"properties": map[string]any{
						"type": map[string]any{
							"type":        "string",
							"description": "Filter by event type: trip, refuel, repair, inspection, accident, recall, warning, maintenance, prediction, diagnostic, part_replacement, note",
						},
						"limit": map[string]any{
							"type":        "integer",
							"description": "Maximum number of events to return (default 20, max 50)",
						},
					},
				},
			},
		},
		{
			Type: "function",
			Function: provider.AIFunctionSchema{
				Name:        "create_vehicle_event",
				Description: "Create a new event for the current vehicle. Use this to log maintenance, repairs, trips, and other vehicle events. Always confirm details with the user before creating.",
				Parameters: map[string]any{
					"type": "object",
					"properties": map[string]any{
						"type": map[string]any{
							"type":        "string",
							"description": "Event type: trip, refuel, repair, inspection, accident, recall, warning, maintenance, prediction, diagnostic, part_replacement, note",
						},
						"title": map[string]any{
							"type":        "string",
							"description": "Short title for the event",
						},
						"description": map[string]any{
							"type":        "string",
							"description": "Detailed description of the event",
						},
						"mileage_km": map[string]any{
							"type":        "integer",
							"description": "Vehicle mileage at the time of the event in kilometers",
						},
						"cost": map[string]any{
							"type":        "number",
							"description": "Cost of the event in rubles",
						},
						"event_date": map[string]any{
							"type":        "string",
							"description": "Date of the event in RFC3339 format (e.g. 2024-01-15T12:00:00Z)",
						},
					},
					"required": []string{"type", "title", "mileage_km", "event_date"},
				},
			},
		},
		{
			Type: "function",
			Function: provider.AIFunctionSchema{
				Name:        "update_vehicle_mileage",
				Description: "Update the current vehicle's mileage. The new mileage must be non-negative.",
				Parameters: map[string]any{
					"type": "object",
					"properties": map[string]any{
						"mileage_km": map[string]any{
							"type":        "integer",
							"description": "New mileage in kilometers",
						},
					},
					"required": []string{"mileage_km"},
				},
			},
		},
		{
			Type: "function",
			Function: provider.AIFunctionSchema{
				Name:        "get_predictions",
				Description: "Get maintenance predictions for the current vehicle, including risk levels, remaining kilometers, and recommendations for each part",
				Parameters: map[string]any{
					"type":       "object",
					"properties": map[string]any{},
				},
			},
		},
	}
}

func (d *ToolDispatcher) getVehicleProfile(ctx context.Context, toolCtx ToolContext) (string, error) {
	vehicle, err := d.vehicles.GetByIDForUser(ctx, toolCtx.UserID, toolCtx.VehicleID)
	if err != nil {
		return "", fmt.Errorf("get vehicle profile: %w", err)
	}

	data, err := json.Marshal(vehicle)
	if err != nil {
		return "", fmt.Errorf("marshal vehicle profile: %w", err)
	}

	return string(data), nil
}

type listEventsArgs struct {
	Type  *string `json:"type"`
	Limit *int    `json:"limit"`
}

func (d *ToolDispatcher) listVehicleEvents(ctx context.Context, toolCtx ToolContext, argsJSON string) (string, error) {
	var args listEventsArgs
	if argsJSON != "" {
		if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
			return "", fmt.Errorf("parse list_vehicle_events arguments: %w", err)
		}
	}

	limit := 20
	if args.Limit != nil && *args.Limit > 0 {
		limit = *args.Limit
		if limit > 50 {
			limit = 50
		}
	}

	filter := repository.VehicleEventFilter{
		Limit:  limit,
		Offset: 0,
	}

	if args.Type != nil {
		eventType := domain.EventType(*args.Type)
		if eventType.IsValid() {
			filter.Type = &eventType
		}
	}

	events, err := d.events.ListByVehicleForUser(ctx, toolCtx.UserID, toolCtx.VehicleID, filter)
	if err != nil {
		return "", fmt.Errorf("list vehicle events: %w", err)
	}

	data, err := json.Marshal(events)
	if err != nil {
		return "", fmt.Errorf("marshal vehicle events: %w", err)
	}

	return string(data), nil
}

type createEventArgs struct {
	Type        string  `json:"type"`
	Title       string  `json:"title"`
	Description *string `json:"description"`
	MileageKM   int     `json:"mileage_km"`
	Cost        float64 `json:"cost"`
	EventDate   string  `json:"event_date"`
}

func (d *ToolDispatcher) createVehicleEvent(ctx context.Context, toolCtx ToolContext, argsJSON string) (string, error) {
	var args createEventArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("parse create_vehicle_event arguments: %w", err)
	}

	eventType := domain.EventType(args.Type)
	if !eventType.IsValid() {
		return "", fmt.Errorf("invalid event type: %s", args.Type)
	}

	if args.Title == "" {
		return "", fmt.Errorf("event title is required")
	}

	if args.MileageKM < 0 {
		return "", fmt.Errorf("mileage cannot be negative")
	}

	if args.Cost < 0 {
		return "", fmt.Errorf("cost cannot be negative")
	}

	eventDate, err := time.Parse(time.RFC3339, args.EventDate)
	if err != nil {
		return "", fmt.Errorf("invalid event_date format, expected RFC3339: %w", err)
	}

	event, err := d.events.CreateForUser(ctx, toolCtx.UserID, domain.VehicleEvent{
		VehicleID:   toolCtx.VehicleID,
		Type:        eventType,
		Title:       args.Title,
		Description: args.Description,
		MileageKM:   args.MileageKM,
		Cost:        args.Cost,
		EventDate:   eventDate,
		Metadata:    map[string]any{},
	})
	if err != nil {
		return "", fmt.Errorf("create vehicle event: %w", err)
	}

	data, err := json.Marshal(event)
	if err != nil {
		return "", fmt.Errorf("marshal created event: %w", err)
	}

	return string(data), nil
}

type updateMileageArgs struct {
	MileageKM int `json:"mileage_km"`
}

func (d *ToolDispatcher) updateVehicleMileage(ctx context.Context, toolCtx ToolContext, argsJSON string) (string, error) {
	var args updateMileageArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("parse update_vehicle_mileage arguments: %w", err)
	}

	if args.MileageKM < 0 {
		return "", fmt.Errorf("mileage cannot be negative")
	}

	vehicle, err := d.vehicles.Update(ctx, toolCtx.UserID, toolCtx.VehicleID, repository.VehicleUpdate{
		MileageKM: &args.MileageKM,
	})
	if err != nil {
		return "", fmt.Errorf("update vehicle mileage: %w", err)
	}

	data, err := json.Marshal(vehicle)
	if err != nil {
		return "", fmt.Errorf("marshal updated vehicle: %w", err)
	}

	return string(data), nil
}

func (d *ToolDispatcher) getPredictions(ctx context.Context, toolCtx ToolContext) (string, error) {
	predictions, err := d.predictions.GetOrGenerate(ctx, toolCtx.UserID, toolCtx.VehicleID)
	if err != nil {
		return "", fmt.Errorf("get predictions: %w", err)
	}

	data, err := json.Marshal(predictions)
	if err != nil {
		return "", fmt.Errorf("marshal predictions: %w", err)
	}

	return string(data), nil
}
