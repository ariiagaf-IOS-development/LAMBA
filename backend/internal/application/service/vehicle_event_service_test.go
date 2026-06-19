package service

import (
	"context"
	"testing"
	"time"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

func TestVehicleEventService_Create_InvalidType(t *testing.T) {
	service := NewVehicleEventService(nil, nil, nil)

	_, err := service.Create(context.Background(), 1, 1, CreateVehicleEventInput{
		Type:      domain.EventType("invalid"),
		Title:     "Test",
		MileageKM: 100,
		Cost:      0,
		EventDate: time.Now(),
	})

	if err != ErrVehicleEventInvalidType {
		t.Fatalf("expected ErrVehicleEventInvalidType, got %v", err)
	}
}

func TestVehicleEventService_Create_EmptyTitle(t *testing.T) {
	service := NewVehicleEventService(nil, nil, nil)

	_, err := service.Create(context.Background(), 1, 1, CreateVehicleEventInput{
		Type:      domain.EventTypeRepair,
		Title:     "   ",
		MileageKM: 100,
		Cost:      0,
		EventDate: time.Now(),
	})

	if err != ErrVehicleEventTitleEmpty {
		t.Fatalf("expected ErrVehicleEventTitleEmpty, got %v", err)
	}
}

func TestVehicleEventService_Create_NegativeMileage(t *testing.T) {
	service := NewVehicleEventService(nil, nil, nil)

	_, err := service.Create(context.Background(), 1, 1, CreateVehicleEventInput{
		Type:      domain.EventTypeRepair,
		Title:     "Repair",
		MileageKM: -1,
		Cost:      0,
		EventDate: time.Now(),
	})

	if err != ErrVehicleEventMileage {
		t.Fatalf("expected ErrVehicleEventMileage, got %v", err)
	}
}

func TestVehicleEventService_Create_NegativeCost(t *testing.T) {
	service := NewVehicleEventService(nil, nil, nil)

	_, err := service.Create(context.Background(), 1, 1, CreateVehicleEventInput{
		Type:      domain.EventTypeRepair,
		Title:     "Repair",
		MileageKM: 100,
		Cost:      -1,
		EventDate: time.Now(),
	})

	if err != ErrVehicleEventCost {
		t.Fatalf("expected ErrVehicleEventCost, got %v", err)
	}
}

func TestVehicleEventService_Create_EmptyDate(t *testing.T) {
	service := NewVehicleEventService(nil, nil, nil)

	_, err := service.Create(context.Background(), 1, 1, CreateVehicleEventInput{
		Type:      domain.EventTypeRepair,
		Title:     "Repair",
		MileageKM: 100,
		Cost:      0,
	})

	if err != ErrVehicleEventDateRequired {
		t.Fatalf("expected ErrVehicleEventDateRequired, got %v", err)
	}
}

func TestNormalizeVehicleEventFilter_DefaultLimit(t *testing.T) {
	filter, err := normalizeVehicleEventFilter(ListVehicleEventsInput{})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if filter.Limit != DefaultVehicleEventLimit {
		t.Fatalf("expected default limit %d, got %d", DefaultVehicleEventLimit, filter.Limit)
	}
	if filter.Offset != 0 {
		t.Fatalf("expected offset 0, got %d", filter.Offset)
	}
}

func TestNormalizeVehicleEventFilter_MaxLimit(t *testing.T) {
	filter, err := normalizeVehicleEventFilter(ListVehicleEventsInput{
		Limit: MaxVehicleEventLimit + 50,
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if filter.Limit != MaxVehicleEventLimit {
		t.Fatalf("expected max limit %d, got %d", MaxVehicleEventLimit, filter.Limit)
	}
}

func TestNormalizeVehicleEventFilter_NegativeLimit(t *testing.T) {
	_, err := normalizeVehicleEventFilter(ListVehicleEventsInput{
		Limit: -1,
	})

	if err != ErrVehicleEventLimit {
		t.Fatalf("expected ErrVehicleEventLimit, got %v", err)
	}
}

func TestNormalizeVehicleEventFilter_NegativeOffset(t *testing.T) {
	_, err := normalizeVehicleEventFilter(ListVehicleEventsInput{
		Offset: -1,
	})

	if err != ErrVehicleEventOffset {
		t.Fatalf("expected ErrVehicleEventOffset, got %v", err)
	}
}

func TestNormalizeVehicleEventFilter_InvalidType(t *testing.T) {
	eventType := domain.EventType("invalid")

	_, err := normalizeVehicleEventFilter(ListVehicleEventsInput{
		Type: &eventType,
	})

	if err != ErrVehicleEventInvalidType {
		t.Fatalf("expected ErrVehicleEventInvalidType, got %v", err)
	}
}
