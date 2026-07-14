package router

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"regexp"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gin-gonic/gin"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/config"
	"golang.org/x/crypto/bcrypt"
)

const (
	testEmail     = "driver@example.com"
	testPassword  = "password123"
	testFirstName = "Ivan"
	testLastName  = "Petrov"
)

func testRouter(t *testing.T) (*gin.Engine, sqlmock.Sqlmock, func()) {
	t.Helper()
	gin.SetMode(gin.TestMode)

	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}

	r := New(Dependencies{
		DB: db,
		Config: config.Config{
			BcryptCost:         bcrypt.MinCost,
			PredictionProvider: config.PredictionProviderMock,
		},
	})

	return r, mock, func() { db.Close() }
}

func basicAuth(email, password string) string {
	return "Basic " + base64.StdEncoding.EncodeToString([]byte(email+":"+password))
}

func testPasswordHash(t *testing.T) string {
	t.Helper()
	hash, err := bcrypt.GenerateFromPassword([]byte(testPassword), bcrypt.MinCost)
	if err != nil {
		t.Fatal(err)
	}
	return string(hash)
}

func expectAuthLookup(mock sqlmock.Sqlmock, hash string) {
	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, email, first_name, last_name, password_hash, created_at FROM users")).
		WithArgs(testEmail).
		WillReturnRows(sqlmock.NewRows([]string{"id", "email", "first_name", "last_name", "password_hash", "created_at"}).
			AddRow(int64(1), testEmail, testFirstName, testLastName, hash, time.Now()))
}

func TestE2E_Register_Success(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	mock.ExpectQuery(regexp.QuoteMeta("INSERT INTO users")).
		WithArgs(testEmail, sqlmock.AnyArg(), testFirstName, testLastName).
		WillReturnRows(sqlmock.NewRows([]string{"id", "email", "first_name", "last_name", "password_hash", "created_at"}).
			AddRow(int64(1), testEmail, testFirstName, testLastName, "hash", time.Now()))

	body, _ := json.Marshal(map[string]string{
		"email":      testEmail,
		"password":   testPassword,
		"first_name": testFirstName,
		"last_name":  testLastName,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/auth/register", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]any
	json.Unmarshal(rec.Body.Bytes(), &resp)
	if resp["token_type"] != "Basic" {
		t.Fatalf("expected token_type Basic, got %v", resp["token_type"])
	}
	if resp["token"] == nil || resp["token"] == "" {
		t.Fatal("expected non-empty token")
	}
}

func TestE2E_Login_Success(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, email, first_name, last_name, password_hash, created_at FROM users")).
		WithArgs(testEmail).
		WillReturnRows(sqlmock.NewRows([]string{"id", "email", "first_name", "last_name", "password_hash", "created_at"}).
			AddRow(int64(1), testEmail, testFirstName, testLastName, hash, time.Now()))

	body, _ := json.Marshal(map[string]string{
		"email":    testEmail,
		"password": testPassword,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/auth/login", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]any
	json.Unmarshal(rec.Body.Bytes(), &resp)
	user := resp["user"].(map[string]any)
	if user["email"] != testEmail {
		t.Fatalf("expected email %s, got %v", testEmail, user["email"])
	}
}

func TestE2E_Login_WrongPassword(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, email, first_name, last_name, password_hash, created_at FROM users")).
		WithArgs(testEmail).
		WillReturnRows(sqlmock.NewRows([]string{"id", "email", "first_name", "last_name", "password_hash", "created_at"}).
			AddRow(int64(1), testEmail, testFirstName, testLastName, hash, time.Now()))

	body, _ := json.Marshal(map[string]string{
		"email":    testEmail,
		"password": "wrongpassword",
	})

	req := httptest.NewRequest(http.MethodPost, "/api/auth/login", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestE2E_Me_Authenticated(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	req := httptest.NewRequest(http.MethodGet, "/api/me", nil)
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]any
	json.Unmarshal(rec.Body.Bytes(), &resp)
	if resp["email"] != testEmail {
		t.Fatalf("expected email %s, got %v", testEmail, resp["email"])
	}
}

func TestE2E_CreateVehicle_Success(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	now := time.Now()
	mock.ExpectQuery(regexp.QuoteMeta("INSERT INTO vehicles")).
		WithArgs(int64(1), "Toyota", "Camry", 2020, sqlmock.AnyArg(), 42000, sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "user_id", "brand", "model", "year", "vin",
			"mileage_km", "fuel_type", "transmission", "usage_type",
			"created_at", "updated_at",
		}).AddRow(int64(1), int64(1), "Toyota", "Camry", 2020, nil, 42000, nil, nil, nil, now, now))

	body, _ := json.Marshal(map[string]any{
		"brand":      "Toyota",
		"model":      "Camry",
		"year":       2020,
		"mileage_km": 42000,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/vehicles", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]any
	json.Unmarshal(rec.Body.Bytes(), &resp)
	if resp["brand"] != "Toyota" {
		t.Fatalf("expected brand Toyota, got %v", resp["brand"])
	}
}

func TestE2E_CreateVehicle_ValidationError(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	body, _ := json.Marshal(map[string]any{
		"brand":      "Toyota",
		"model":      "Camry",
		"year":       1800,
		"mileage_km": 42000,
	})

	req := httptest.NewRequest(http.MethodPost, "/api/vehicles", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestE2E_ListVehicles_Success(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

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

	req := httptest.NewRequest(http.MethodGet, "/api/vehicles", nil)
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]any
	json.Unmarshal(rec.Body.Bytes(), &resp)
	vehicles := resp["vehicles"].([]any)
	if len(vehicles) != 2 {
		t.Fatalf("expected 2 vehicles, got %d", len(vehicles))
	}
}

func TestE2E_ListVehicles_Empty(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, user_id, brand, model, year, vin, mileage_km, fuel_type, transmission, usage_type, created_at, updated_at FROM vehicles")).
		WithArgs(int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "user_id", "brand", "model", "year", "vin",
			"mileage_km", "fuel_type", "transmission", "usage_type",
			"created_at", "updated_at",
		}))

	req := httptest.NewRequest(http.MethodGet, "/api/vehicles", nil)
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]any
	json.Unmarshal(rec.Body.Bytes(), &resp)
	vehicles := resp["vehicles"].([]any)
	if len(vehicles) != 0 {
		t.Fatalf("expected 0 vehicles, got %d", len(vehicles))
	}
}

func TestE2E_GetVehicle_Success(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	now := time.Now()
	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, user_id, brand, model, year, vin, mileage_km, fuel_type, transmission, usage_type, created_at, updated_at FROM vehicles")).
		WithArgs(int64(1), int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "user_id", "brand", "model", "year", "vin",
			"mileage_km", "fuel_type", "transmission", "usage_type",
			"created_at", "updated_at",
		}).AddRow(int64(1), int64(1), "Toyota", "Camry", 2020, nil, 42000, nil, nil, nil, now, now))

	req := httptest.NewRequest(http.MethodGet, "/api/vehicles/1", nil)
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]any
	json.Unmarshal(rec.Body.Bytes(), &resp)
	if resp["brand"] != "Toyota" {
		t.Fatalf("expected brand Toyota, got %v", resp["brand"])
	}
}

func TestE2E_GetVehicle_NotFound(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, user_id, brand, model, year, vin, mileage_km, fuel_type, transmission, usage_type, created_at, updated_at FROM vehicles")).
		WithArgs(int64(1), int64(999)).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "user_id", "brand", "model", "year", "vin",
			"mileage_km", "fuel_type", "transmission", "usage_type",
			"created_at", "updated_at",
		}))

	req := httptest.NewRequest(http.MethodGet, "/api/vehicles/999", nil)
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestE2E_DeleteVehicle_Success(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	mock.ExpectExec(regexp.QuoteMeta("DELETE FROM vehicles")).
		WithArgs(int64(1), int64(1)).
		WillReturnResult(sqlmock.NewResult(0, 1))

	req := httptest.NewRequest(http.MethodDelete, "/api/vehicles/1", nil)
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestE2E_DeleteVehicle_NotFound(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	mock.ExpectExec(regexp.QuoteMeta("DELETE FROM vehicles")).
		WithArgs(int64(1), int64(999)).
		WillReturnResult(sqlmock.NewResult(0, 0))

	req := httptest.NewRequest(http.MethodDelete, "/api/vehicles/999", nil)
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestE2E_CreateEvent_Success(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	eventDate := time.Date(2026, 6, 3, 12, 0, 0, 0, time.UTC)
	createdAt := time.Now()

	mock.ExpectQuery(regexp.QuoteMeta("INSERT INTO vehicle_events")).
		WithArgs(int64(1), int64(1), "repair", "Oil change", sqlmock.AnyArg(), 50000, 5000.0, eventDate, sqlmock.AnyArg()).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "vehicle_id", "type", "title", "description",
			"mileage_km", "cost", "event_date", "metadata", "created_at",
		}).AddRow(int64(1), int64(1), "repair", "Oil change", nil, 50000, 5000.0, eventDate, []byte("{}"), createdAt))

	body, _ := json.Marshal(map[string]any{
		"type":       "repair",
		"title":      "Oil change",
		"mileage_km": 50000,
		"cost":       5000,
		"event_date": eventDate.Format(time.RFC3339),
	})

	req := httptest.NewRequest(http.MethodPost, "/api/vehicles/1/events", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestE2E_CreateEvent_InvalidType(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	body, _ := json.Marshal(map[string]any{
		"type":       "invalid_type",
		"title":      "Test",
		"mileage_km": 50000,
		"cost":       0,
		"event_date": time.Now().Format(time.RFC3339),
	})

	req := httptest.NewRequest(http.MethodPost, "/api/vehicles/1/events", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestE2E_ListEvents_Success(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	eventDate := time.Date(2026, 6, 3, 12, 0, 0, 0, time.UTC)
	createdAt := time.Now()

	mock.ExpectQuery("SELECT(.|\n)*FROM vehicle_events ve").
		WithArgs(int64(1), int64(1), 20, 0).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "vehicle_id", "type", "title", "description",
			"mileage_km", "cost", "event_date", "metadata", "created_at",
		}).
			AddRow(int64(1), int64(1), "repair", "Oil change", nil, 50000, 5000.0, eventDate, []byte("{}"), createdAt).
			AddRow(int64(2), int64(1), "refuel", "Fuel up", nil, 50100, 3000.0, eventDate, []byte("{}"), createdAt))

	req := httptest.NewRequest(http.MethodGet, "/api/vehicles/1/events", nil)
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]any
	json.Unmarshal(rec.Body.Bytes(), &resp)
	events := resp["events"].([]any)
	if len(events) != 2 {
		t.Fatalf("expected 2 events, got %d", len(events))
	}
	if resp["count"].(float64) != 2 {
		t.Fatalf("expected count 2, got %v", resp["count"])
	}
}

func TestE2E_ListEvents_WithTypeFilter(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	eventDate := time.Date(2026, 6, 3, 12, 0, 0, 0, time.UTC)
	createdAt := time.Now()

	mock.ExpectQuery("SELECT(.|\n)*FROM vehicle_events ve").
		WithArgs(int64(1), int64(1), "refuel", 20, 0).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "vehicle_id", "type", "title", "description",
			"mileage_km", "cost", "event_date", "metadata", "created_at",
		}).AddRow(int64(2), int64(1), "refuel", "Fuel up", nil, 50100, 3000.0, eventDate, []byte("{}"), createdAt))

	req := httptest.NewRequest(http.MethodGet, "/api/vehicles/1/events?type=refuel", nil)
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]any
	json.Unmarshal(rec.Body.Bytes(), &resp)
	events := resp["events"].([]any)
	if len(events) != 1 {
		t.Fatalf("expected 1 filtered event, got %d", len(events))
	}
}

func TestE2E_DeleteEvent_Success(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	mock.ExpectExec(regexp.QuoteMeta("DELETE FROM vehicle_events ve")).
		WithArgs(int64(1), int64(1), int64(1)).
		WillReturnResult(sqlmock.NewResult(0, 1))

	req := httptest.NewRequest(http.MethodDelete, "/api/vehicles/1/events/1", nil)
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestE2E_EventStats_Success(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	mock.ExpectQuery(regexp.QuoteMeta("SELECT EXISTS")).
		WithArgs(int64(1), int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{"exists"}).AddRow(true))

	mock.ExpectQuery("SELECT(.|\n)*COUNT").
		WithArgs(int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{"count", "sum"}).AddRow(int64(5), 25000.0))

	mock.ExpectQuery("SELECT(.|\n)*type").
		WithArgs(int64(1)).
		WillReturnRows(sqlmock.NewRows([]string{"type", "count", "sum"}).
			AddRow("repair", int64(2), 15000.0).
			AddRow("refuel", int64(3), 10000.0))

	req := httptest.NewRequest(http.MethodGet, "/api/vehicles/1/events/stats", nil)
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]any
	json.Unmarshal(rec.Body.Bytes(), &resp)
	stats := resp["stats"].(map[string]any)
	if stats["total_events"].(float64) != 5 {
		t.Fatalf("expected 5 total events, got %v", stats["total_events"])
	}
	if stats["total_cost"].(float64) != 25000 {
		t.Fatalf("expected 25000 total cost, got %v", stats["total_cost"])
	}
}

func TestE2E_Timeline_Success(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	eventDate := time.Date(2026, 6, 3, 12, 0, 0, 0, time.UTC)
	createdAt := time.Now()

	mock.ExpectQuery("SELECT(.|\n)*FROM vehicle_events ve").
		WithArgs(int64(1), int64(1), 20, 0).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "vehicle_id", "type", "title", "description",
			"mileage_km", "cost", "event_date", "metadata", "created_at",
		}).AddRow(int64(1), int64(1), "repair", "Oil change", nil, 50000, 5000.0, eventDate, []byte("{}"), createdAt))

	req := httptest.NewRequest(http.MethodGet, "/api/vehicles/1/timeline", nil)
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]any
	json.Unmarshal(rec.Body.Bytes(), &resp)
	timeline := resp["timeline"].([]any)
	if len(timeline) != 1 {
		t.Fatalf("expected 1 timeline event, got %d", len(timeline))
	}
}

func TestE2E_ListCatalog_Success(t *testing.T) {
	r, mock, cleanup := testRouter(t)
	defer cleanup()

	hash := testPasswordHash(t)
	expectAuthLookup(mock, hash)

	mock.ExpectQuery(regexp.QuoteMeta("SELECT id, code, name, category, default_lifetime_km, default_lifetime_days, created_at FROM parts_catalog")).
		WillReturnRows(sqlmock.NewRows([]string{
			"id", "code", "name", "category", "default_lifetime_km", "default_lifetime_days", "created_at",
		}).
			AddRow(int64(1), "engine_oil", "Engine Oil", "fluids", 10000, 365, time.Now()).
			AddRow(int64(2), "brake_pads", "Brake Pads", "brakes", 30000, 730, time.Now()))

	req := httptest.NewRequest(http.MethodGet, "/api/parts/catalog", nil)
	req.Header.Set("Authorization", basicAuth(testEmail, testPassword))
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var resp map[string]any
	json.Unmarshal(rec.Body.Bytes(), &resp)
	parts := resp["parts"].([]any)
	if len(parts) != 2 {
		t.Fatalf("expected 2 catalog parts, got %d", len(parts))
	}
}

func TestE2E_AllProtectedRoutes_RequireAuth(t *testing.T) {
	r, _, cleanup := testRouter(t)
	defer cleanup()

	routes := []struct {
		method string
		path   string
	}{
		{http.MethodGet, "/api/me"},
		{http.MethodPost, "/api/vehicles"},
		{http.MethodGet, "/api/vehicles"},
		{http.MethodGet, "/api/vehicles/1"},
		{http.MethodPatch, "/api/vehicles/1"},
		{http.MethodDelete, "/api/vehicles/1"},
		{http.MethodPost, "/api/vehicles/1/events"},
		{http.MethodGet, "/api/vehicles/1/events"},
		{http.MethodGet, "/api/vehicles/1/events/stats"},
		{http.MethodGet, "/api/vehicles/1/timeline"},
		{http.MethodPatch, "/api/vehicles/1/events/1"},
		{http.MethodDelete, "/api/vehicles/1/events/1"},
		{http.MethodGet, "/api/vehicles/1/predictions"},
		{http.MethodPost, "/api/vehicles/1/predictions/refresh"},
		{http.MethodGet, "/api/vehicles/1/dashboard"},
		{http.MethodPost, "/api/vehicles/1/chat"},
		{http.MethodGet, "/api/vehicles/1/chat/history"},
		{http.MethodGet, "/api/parts/catalog"},
		{http.MethodGet, "/api/vehicles/1/parts"},
		{http.MethodPost, "/api/vehicles/1/parts"},
		{http.MethodDelete, "/api/vehicles/1/parts/1"},
	}

	for _, rt := range routes {
		name := fmt.Sprintf("%s %s", rt.method, rt.path)
		t.Run(name, func(t *testing.T) {
			req := httptest.NewRequest(rt.method, rt.path, nil)
			rec := httptest.NewRecorder()
			r.ServeHTTP(rec, req)

			if rec.Code != http.StatusUnauthorized {
				t.Fatalf("expected 401, got %d", rec.Code)
			}
		})
	}
}

func TestE2E_PublicRoutes_NoAuthRequired(t *testing.T) {
	r, _, cleanup := testRouter(t)
	defer cleanup()

	routes := []struct {
		method string
		path   string
	}{
		{http.MethodGet, "/health"},
	}

	for _, rt := range routes {
		t.Run(fmt.Sprintf("%s %s", rt.method, rt.path), func(t *testing.T) {
			req := httptest.NewRequest(rt.method, rt.path, nil)
			rec := httptest.NewRecorder()
			r.ServeHTTP(rec, req)

			if rec.Code == http.StatusUnauthorized {
				t.Fatalf("expected public route, got 401")
			}
		})
	}
}

func TestE2E_InternalPushPredictions_NoAuth(t *testing.T) {
	r, _, cleanup := testRouter(t)
	defer cleanup()

	req := httptest.NewRequest(http.MethodPost, "/api/internal/vehicles/abc/predictions", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code == http.StatusUnauthorized {
		t.Fatal("internal route should not require auth")
	}
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for invalid ID, got %d", rec.Code)
	}
}
