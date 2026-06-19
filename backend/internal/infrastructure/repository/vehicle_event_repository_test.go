package repository

import (
	"context"
	"database/sql/driver"
	"encoding/json"
	"regexp"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

func TestVehicleEventRepository_CreateForUser(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	repo := NewVehicleEventRepository(db)

	eventDate := time.Date(2026, 6, 3, 12, 0, 0, 0, time.UTC)
	createdAt := time.Date(2026, 6, 3, 12, 1, 0, 0, time.UTC)

	metadata := map[string]any{
		"part": "engine_oil",
	}

	metadataBytes, _ := json.Marshal(metadata)

	rows := sqlmock.NewRows([]string{
		"id",
		"vehicle_id",
		"type",
		"title",
		"description",
		"mileage_km",
		"cost",
		"event_date",
		"metadata",
		"created_at",
	}).AddRow(
		int64(10),
		int64(1),
		domain.EventTypeMaintenance,
		"Замена масла",
		"Масло 5W-30",
		124500,
		7500.0,
		eventDate,
		metadataBytes,
		createdAt,
	)

	mock.ExpectQuery(regexp.QuoteMeta(`
		INSERT INTO vehicle_events (
			vehicle_id,
			type,
			title,
			description,
			mileage_km,
			cost,
			event_date,
			metadata
		)
		SELECT
			$1, $3, $4, $5, $6, $7, $8, $9
		WHERE EXISTS (
			SELECT 1
			FROM vehicles
			WHERE id = $1 AND user_id = $2
		)
		RETURNING
			id,
			vehicle_id,
			type,
			title,
			description,
			mileage_km,
			cost,
			event_date,
			metadata,
			created_at
	`)).
		WithArgs(
			int64(1),
			int64(100),
			domain.EventTypeMaintenance,
			"Замена масла",
			stringPtr("Масло 5W-30"),
			124500,
			7500.0,
			eventDate,
			sqlmock.AnyArg(),
		).
		WillReturnRows(rows)

	got, err := repo.CreateForUser(context.Background(), 100, domain.VehicleEvent{
		VehicleID:   1,
		Type:        domain.EventTypeMaintenance,
		Title:       "Замена масла",
		Description: stringPtr("Масло 5W-30"),
		MileageKM:   124500,
		Cost:        7500,
		EventDate:   eventDate,
		Metadata:    metadata,
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if got.ID != 10 {
		t.Fatalf("expected event id 10, got %d", got.ID)
	}
	if got.Type != domain.EventTypeMaintenance {
		t.Fatalf("expected type %q, got %q", domain.EventTypeMaintenance, got.Type)
	}
	if got.Metadata["part"] != "engine_oil" {
		t.Fatalf("expected metadata part engine_oil, got %#v", got.Metadata)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestVehicleEventRepository_ListByVehicleForUser_WithFilterAndPagination(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	repo := NewVehicleEventRepository(db)

	eventDate := time.Date(2026, 6, 3, 12, 0, 0, 0, time.UTC)
	createdAt := time.Date(2026, 6, 3, 12, 1, 0, 0, time.UTC)

	rows := sqlmock.NewRows([]string{
		"id",
		"vehicle_id",
		"type",
		"title",
		"description",
		"mileage_km",
		"cost",
		"event_date",
		"metadata",
		"created_at",
	}).AddRow(
		int64(1),
		int64(10),
		domain.EventTypeFuel,
		"Заправка",
		nil,
		100000,
		3500.0,
		eventDate,
		[]byte(`{"liters":45}`),
		createdAt,
	)

	eventType := domain.EventTypeFuel

	mock.ExpectQuery("SELECT(.|\n)*FROM vehicle_events ve").
		WithArgs(int64(10), int64(100), eventType, 20, 0).
		WillReturnRows(rows)

	got, err := repo.ListByVehicleForUser(context.Background(), 100, 10, VehicleEventFilter{
		Type:   &eventType,
		Limit:  20,
		Offset: 0,
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(got) != 1 {
		t.Fatalf("expected 1 event, got %d", len(got))
	}
	if got[0].Type != domain.EventTypeFuel {
		t.Fatalf("expected fuel event, got %q", got[0].Type)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestVehicleEventRepository_GetStatsByVehicleForUser(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	repo := NewVehicleEventRepository(db)

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(int64(10), int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{"exists"}).AddRow(true))

	mock.ExpectQuery("SELECT(.|\n)*COUNT").
		WithArgs(int64(10)).
		WillReturnRows(sqlmock.NewRows([]string{"count", "sum"}).AddRow(int64(2), 10500.0))

	mock.ExpectQuery("SELECT(.|\n)*type").
		WithArgs(int64(10)).
		WillReturnRows(sqlmock.NewRows([]string{"type", "count", "sum"}).
			AddRow(domain.EventTypeFuel, int64(1), 3500.0).
			AddRow(domain.EventTypeMaintenance, int64(1), 7000.0),
		)

	stats, err := repo.GetStatsByVehicleForUser(context.Background(), 1, 10)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if stats.TotalEvents != 2 {
		t.Fatalf("expected 2 events, got %d", stats.TotalEvents)
	}
	if stats.TotalCost != 10500 {
		t.Fatalf("expected total cost 10500, got %f", stats.TotalCost)
	}
	if len(stats.ByType) != 2 {
		t.Fatalf("expected 2 type stats, got %d", len(stats.ByType))
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func stringPtr(value string) *string {
	return &value
}

var _ driver.Value
