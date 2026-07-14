package service

import (
	"context"
	"regexp"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/application/provider"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
	"golang.org/x/crypto/bcrypt"
)

func TestIntegration_AuthService_Register(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	userRepo := repository.NewUserRepository(db)
	authService := NewAuthService(userRepo, bcrypt.MinCost)

	mock.ExpectQuery(regexp.QuoteMeta("INSERT INTO users")).
		WithArgs("test@example.com", sqlmock.AnyArg(), "Ivan", "Petrov").
		WillReturnRows(sqlmock.NewRows([]string{"id", "email", "first_name", "last_name", "password_hash", "created_at"}).
			AddRow(int64(1), "test@example.com", "Ivan", "Petrov", "hash", time.Now()))

	user, err := authService.Register(context.Background(), "test@example.com", "password123", "Ivan", "Petrov")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if user.ID != 1 {
		t.Fatalf("expected user ID 1, got %d", user.ID)
	}
	if user.Email != "test@example.com" {
		t.Fatalf("expected email test@example.com, got %s", user.Email)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestIntegration_AuthService_Register_EmailTaken(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	userRepo := repository.NewUserRepository(db)
	authService := NewAuthService(userRepo, bcrypt.MinCost)

	mock.ExpectQuery(regexp.QuoteMeta("INSERT INTO users")).
		WithArgs("taken@example.com", sqlmock.AnyArg(), "", "").
		WillReturnError(repository.ErrConflict)

	_, err = authService.Register(context.Background(), "taken@example.com", "password123", "", "")
	if err != ErrEmailTaken {
		t.Fatalf("expected ErrEmailTaken, got %v", err)
	}
}

func TestIntegration_AuthService_Login(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	hash, _ := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.MinCost)

	userRepo := repository.NewUserRepository(db)
	authService := NewAuthService(userRepo, bcrypt.MinCost)

	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, email, first_name, last_name, password_hash, created_at FROM users")).
		WithArgs("test@example.com").
		WillReturnRows(sqlmock.NewRows([]string{"id", "email", "first_name", "last_name", "password_hash", "created_at"}).
			AddRow(int64(1), "test@example.com", "Ivan", "Petrov", string(hash), time.Now()))

	user, err := authService.Login(context.Background(), "test@example.com", "password123")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if user.Email != "test@example.com" {
		t.Fatalf("expected email test@example.com, got %s", user.Email)
	}
}

func TestIntegration_AuthService_Login_UserNotFound(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	userRepo := repository.NewUserRepository(db)
	authService := NewAuthService(userRepo, bcrypt.MinCost)

	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, email, first_name, last_name, password_hash, created_at FROM users")).
		WithArgs("nobody@example.com").
		WillReturnError(repository.ErrNotFound)

	_, err = authService.Login(context.Background(), "nobody@example.com", "password123")
	if err != ErrInvalidCredentials {
		t.Fatalf("expected ErrInvalidCredentials, got %v", err)
	}
}

func TestIntegration_AuthService_Login_WrongPassword(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	hash, _ := bcrypt.GenerateFromPassword([]byte("correct_password"), bcrypt.MinCost)

	userRepo := repository.NewUserRepository(db)
	authService := NewAuthService(userRepo, bcrypt.MinCost)

	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, email, first_name, last_name, password_hash, created_at FROM users")).
		WithArgs("test@example.com").
		WillReturnRows(sqlmock.NewRows([]string{"id", "email", "first_name", "last_name", "password_hash", "created_at"}).
			AddRow(int64(1), "test@example.com", "Ivan", "Petrov", string(hash), time.Now()))

	_, err = authService.Login(context.Background(), "test@example.com", "wrong_password")
	if err != ErrInvalidCredentials {
		t.Fatalf("expected ErrInvalidCredentials, got %v", err)
	}
}

func TestIntegration_AuthService_Authenticate_EmptyPassword(t *testing.T) {
	db, _, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	userRepo := repository.NewUserRepository(db)
	authService := NewAuthService(userRepo, bcrypt.MinCost)

	_, err = authService.Authenticate(context.Background(), "test@example.com", "  ")
	if err != ErrInvalidCredentials {
		t.Fatalf("expected ErrInvalidCredentials, got %v", err)
	}
}

func TestIntegration_VehicleService_Create(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	vehicleRepo := repository.NewVehicleRepository(db)
	vehicleService := NewVehicleService(vehicleRepo)

	now := time.Now()
	mock.ExpectQuery(regexp.QuoteMeta("INSERT INTO vehicles")).
		WithArgs(int64(1), "Toyota", "Camry", 2020, sqlmock.AnyArg(), 42000, sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "user_id", "brand", "model", "year", "vin",
			"mileage_km", "fuel_type", "transmission", "usage_type",
			"created_at", "updated_at",
		}).AddRow(int64(1), int64(1), "Toyota", "Camry", 2020, nil, 42000, nil, nil, nil, now, now))

	vehicle, err := vehicleService.Create(context.Background(), 1, CreateVehicleInput{
		Brand:     "Toyota",
		Model:     "Camry",
		Year:      2020,
		MileageKM: 42000,
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if vehicle.Brand != "Toyota" {
		t.Fatalf("expected Toyota, got %s", vehicle.Brand)
	}
	if vehicle.UserID != 1 {
		t.Fatalf("expected user ID 1, got %d", vehicle.UserID)
	}

	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestIntegration_VehicleService_List(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	vehicleRepo := repository.NewVehicleRepository(db)
	vehicleService := NewVehicleService(vehicleRepo)

	now := time.Now()
	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, user_id, brand, model, year, vin, mileage_km, fuel_type, transmission, usage_type, created_at, updated_at FROM vehicles")).
		WithArgs(int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "user_id", "brand", "model", "year", "vin",
			"mileage_km", "fuel_type", "transmission", "usage_type",
			"created_at", "updated_at",
		}).
			AddRow(int64(1), int64(1), "Toyota", "Camry", 2020, nil, 42000, nil, nil, nil, now, now).
			AddRow(int64(2), int64(1), "Honda", "Civic", 2019, nil, 55000, nil, nil, nil, now, now))

	vehicles, err := vehicleService.List(context.Background(), 1)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(vehicles) != 2 {
		t.Fatalf("expected 2 vehicles, got %d", len(vehicles))
	}
}

func TestIntegration_VehicleService_Get(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	vehicleRepo := repository.NewVehicleRepository(db)
	vehicleService := NewVehicleService(vehicleRepo)

	now := time.Now()
	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, user_id, brand, model, year, vin, mileage_km, fuel_type, transmission, usage_type, created_at, updated_at FROM vehicles")).
		WithArgs(int64(1), int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "user_id", "brand", "model", "year", "vin",
			"mileage_km", "fuel_type", "transmission", "usage_type",
			"created_at", "updated_at",
		}).AddRow(int64(1), int64(1), "Toyota", "Camry", 2020, nil, 42000, nil, nil, nil, now, now))

	vehicle, err := vehicleService.Get(context.Background(), 1, 1)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if vehicle.Brand != "Toyota" {
		t.Fatalf("expected Toyota, got %s", vehicle.Brand)
	}
}

func TestIntegration_VehicleService_Delete(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	vehicleRepo := repository.NewVehicleRepository(db)
	vehicleService := NewVehicleService(vehicleRepo)

	mock.ExpectExec(regexp.QuoteMeta("DELETE FROM vehicles")).
		WithArgs(int64(1), int64(1)).
		WillReturnResult(sqlmock.NewResult(0, 1))

	err = vehicleService.Delete(context.Background(), 1, 1)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
}

func TestIntegration_VehicleEventService_Create_Success(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	eventRepo := repository.NewVehicleEventRepository(db)
	eventService := NewVehicleEventService(eventRepo, nil, nil)

	eventDate := time.Date(2026, 6, 3, 12, 0, 0, 0, time.UTC)
	createdAt := time.Now()

	mock.ExpectQuery(regexp.QuoteMeta("INSERT INTO vehicle_events")).
		WithArgs(int64(1), int64(1), domain.EventTypeRefuel, "Fuel up", sqlmock.AnyArg(), 50000, 3000.0, eventDate, sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "vehicle_id", "type", "title", "description",
			"mileage_km", "cost", "event_date", "metadata", "created_at",
		}).AddRow(int64(1), int64(1), domain.EventTypeRefuel, "Fuel up", nil, 50000, 3000.0, eventDate, []byte("{}"), createdAt))

	event, err := eventService.Create(context.Background(), 1, 1, CreateVehicleEventInput{
		Type:      domain.EventTypeRefuel,
		Title:     "Fuel up",
		MileageKM: 50000,
		Cost:      3000,
		EventDate: eventDate,
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if event.Type != domain.EventTypeRefuel {
		t.Fatalf("expected type refuel, got %s", event.Type)
	}
	if event.Title != "Fuel up" {
		t.Fatalf("expected title 'Fuel up', got %s", event.Title)
	}
}

func TestIntegration_VehicleEventService_Stats(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	eventRepo := repository.NewVehicleEventRepository(db)
	eventService := NewVehicleEventService(eventRepo, nil, nil)

	mock.ExpectQuery(regexp.QuoteMeta("SELECT EXISTS")).
		WithArgs(int64(1), int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{"exists"}).AddRow(true))

	mock.ExpectQuery("SELECT(.|\n)*COUNT").
		WithArgs(int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{"count", "sum"}).AddRow(int64(3), 15000.0))

	mock.ExpectQuery("SELECT(.|\n)*type").
		WithArgs(int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{"type", "count", "sum"}).
			AddRow("repair", int64(1), 10000.0).
			AddRow("refuel", int64(2), 5000.0))

	stats, err := eventService.Stats(context.Background(), 1, 1)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if stats.TotalEvents != 3 {
		t.Fatalf("expected 3 events, got %d", stats.TotalEvents)
	}
	if stats.TotalCost != 15000 {
		t.Fatalf("expected cost 15000, got %f", stats.TotalCost)
	}
	if len(stats.ByType) != 2 {
		t.Fatalf("expected 2 type groups, got %d", len(stats.ByType))
	}
}

func TestIntegration_PredictionService_GetOrGenerate_ExistingPredictions(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	vehicleRepo := repository.NewVehicleRepository(db)
	eventRepo := repository.NewVehicleEventRepository(db)
	partRepo := repository.NewPartRepository(db)
	predRepo := repository.NewPredictionRepository(db)
	mockProvider := provider.NewMockPredictionProvider()
	predService := NewPredictionService(vehicleRepo, eventRepo, partRepo, predRepo, mockProvider)

	mock.ExpectQuery("SELECT DISTINCT ON").
		WithArgs(int64(1), int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "vehicle_id", "part_code", "part_name", "part_category",
			"risk_level", "risk_score", "remaining_km", "remaining_days",
			"predicted_next_mileage", "predicted_next_date", "probability",
			"recommendation", "explanation", "source", "model_version", "created_at",
		}).AddRow(
			int64(1), int64(1), nil, "Engine Oil", "fluids",
			"low", 35, 7000, 180,
			57000, nil, 0.35,
			"OK", "All good", "mock", nil, time.Now(),
		))

	predictions, err := predService.GetOrGenerate(context.Background(), 1, 1)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(predictions) != 1 {
		t.Fatalf("expected 1 existing prediction, got %d", len(predictions))
	}
	if predictions[0].PartName != "Engine Oil" {
		t.Fatalf("expected Engine Oil, got %s", predictions[0].PartName)
	}
}

func TestIntegration_DashboardService_Get(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	vehicleRepo := repository.NewVehicleRepository(db)
	eventRepo := repository.NewVehicleEventRepository(db)
	predRepo := repository.NewPredictionRepository(db)
	dashService := NewDashboardService(vehicleRepo, eventRepo, predRepo)

	now := time.Now()

	// GetByIDForUser
	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, user_id, brand, model, year, vin, mileage_km, fuel_type, transmission, usage_type, created_at, updated_at FROM vehicles")).
		WithArgs(int64(1), int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "user_id", "brand", "model", "year", "vin",
			"mileage_km", "fuel_type", "transmission", "usage_type",
			"created_at", "updated_at",
		}).AddRow(int64(1), int64(1), "Toyota", "Camry", 2020, nil, 50000, nil, nil, nil, now, now))

	// GetDashboardStatsByVehicleForUser (ownership check + stats)
	mock.ExpectQuery(regexp.QuoteMeta("SELECT EXISTS")).
		WithArgs(int64(1), int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{"exists"}).AddRow(true))

	mock.ExpectQuery("SELECT(.|\n)*COALESCE").
		WithArgs(int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{
			"maintenance_cost", "fuel_expenses", "repairs_count", "events_count",
		}).AddRow(10000.0, 5000.0, int64(2), int64(5)))

	// ListByVehicleForUser (latest events)
	mock.ExpectQuery("SELECT(.|\n)*FROM vehicle_events ve").
		WithArgs(int64(1), int64(1), 5, 0).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "vehicle_id", "type", "title", "description",
			"mileage_km", "cost", "event_date", "metadata", "created_at",
		}).AddRow(int64(1), int64(1), "repair", "Oil change", nil, 49000, 5000.0, now, []byte("{}"), now))

	// ListLatestByVehicleForUser (predictions)
	mock.ExpectQuery("SELECT DISTINCT ON").
		WithArgs(int64(1), int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "vehicle_id", "part_code", "part_name", "part_category",
			"risk_level", "risk_score", "remaining_km", "remaining_days",
			"predicted_next_mileage", "predicted_next_date", "probability",
			"recommendation", "explanation", "source", "model_version", "created_at",
		}).AddRow(
			int64(1), int64(1), nil, "Engine Oil", "fluids",
			"medium", 65, 3000, 90,
			53000, nil, 0.65,
			"Check soon", "Wear", "rule_based", nil, now,
		))

	dashboard, err := dashService.Get(context.Background(), 1, 1)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if dashboard.Vehicle.Brand != "Toyota" {
		t.Fatalf("expected Toyota, got %s", dashboard.Vehicle.Brand)
	}
	if dashboard.CurrentMileage != 50000 {
		t.Fatalf("expected mileage 50000, got %d", dashboard.CurrentMileage)
	}
	if dashboard.TotalMaintenanceCost != 10000 {
		t.Fatalf("expected maintenance cost 10000, got %f", dashboard.TotalMaintenanceCost)
	}
	if dashboard.TotalEventsCount != 5 {
		t.Fatalf("expected 5 events, got %d", dashboard.TotalEventsCount)
	}
	if len(dashboard.LatestEvents) != 1 {
		t.Fatalf("expected 1 event, got %d", len(dashboard.LatestEvents))
	}
	if dashboard.Status != "attention" {
		t.Fatalf("expected status attention (medium risk), got %s", dashboard.Status)
	}
	if dashboard.PredictionSummary == nil {
		t.Fatal("expected prediction summary")
	}
	if dashboard.PredictionSummary.PartName != "Engine Oil" {
		t.Fatalf("expected part name Engine Oil, got %s", dashboard.PredictionSummary.PartName)
	}
	if len(dashboard.AllPredictions) != 1 {
		t.Fatalf("expected 1 prediction, got %d", len(dashboard.AllPredictions))
	}
}

func TestIntegration_DashboardService_VehicleNotFound(t *testing.T) {
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	vehicleRepo := repository.NewVehicleRepository(db)
	eventRepo := repository.NewVehicleEventRepository(db)
	predRepo := repository.NewPredictionRepository(db)
	dashService := NewDashboardService(vehicleRepo, eventRepo, predRepo)

	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, user_id, brand, model, year, vin, mileage_km, fuel_type, transmission, usage_type, created_at, updated_at FROM vehicles")).
		WithArgs(int64(1), int64(999)).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "user_id", "brand", "model", "year", "vin",
			"mileage_km", "fuel_type", "transmission", "usage_type",
			"created_at", "updated_at",
		}))

	_, err = dashService.Get(context.Background(), 1, 999)
	if err == nil {
		t.Fatal("expected error for not found vehicle")
	}
}
