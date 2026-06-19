package handler

import (
	"context"
	"encoding/base64"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gin-gonic/gin"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/application/service"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/http/middleware"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
)

func TestParseVehicleEventListQuery(t *testing.T) {
	gin.SetMode(gin.TestMode)

	req := httptest.NewRequest(http.MethodGet, "/events?type=fuel&limit=10&offset=20", nil)
	rec := httptest.NewRecorder()

	c, _ := gin.CreateTestContext(rec)
	c.Request = req

	input, ok := parseVehicleEventListQuery(c)
	if !ok {
		t.Fatal("expected query to be parsed")
	}

	if input.Type == nil || *input.Type != domain.EventTypeFuel {
		t.Fatalf("expected type fuel, got %#v", input.Type)
	}
	if input.Limit != 10 {
		t.Fatalf("expected limit 10, got %d", input.Limit)
	}
	if input.Offset != 20 {
		t.Fatalf("expected offset 20, got %d", input.Offset)
	}
}

func TestParseVehicleEventListQuery_InvalidLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)

	req := httptest.NewRequest(http.MethodGet, "/events?limit=abc", nil)
	rec := httptest.NewRecorder()

	c, _ := gin.CreateTestContext(rec)
	c.Request = req

	_, ok := parseVehicleEventListQuery(c)
	if ok {
		t.Fatal("expected parsing to fail")
	}
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", rec.Code)
	}
}

func TestParseVehicleEventListQuery_InvalidOffset(t *testing.T) {
	gin.SetMode(gin.TestMode)

	req := httptest.NewRequest(http.MethodGet, "/events?offset=abc", nil)
	rec := httptest.NewRecorder()

	c, _ := gin.CreateTestContext(rec)
	c.Request = req

	_, ok := parseVehicleEventListQuery(c)
	if ok {
		t.Fatal("expected parsing to fail")
	}
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", rec.Code)
	}
}

func TestNormalizedLimit(t *testing.T) {
	if got := normalizedLimit(0); got != service.DefaultVehicleEventLimit {
		t.Fatalf("expected default limit, got %d", got)
	}

	if got := normalizedLimit(service.MaxVehicleEventLimit + 10); got != service.MaxVehicleEventLimit {
		t.Fatalf("expected max limit, got %d", got)
	}

	if got := normalizedLimit(10); got != 10 {
		t.Fatalf("expected limit 10, got %d", got)
	}
}

func TestVehicleEventHandler_ListEvents_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)

	db, _, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	eventRepo := repository.NewVehicleEventRepository(db)
	eventService := service.NewVehicleEventService(eventRepo, nil, nil)
	h := NewVehicleEventHandler(eventService, nil)

	r := gin.New()
	r.GET("/vehicles/:id/events", h.ListEvents)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/1/events", nil)
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401, got %d", rec.Code)
	}
}

func TestVehicleEventHandler_GetEventStats_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)

	db, _, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	eventRepo := repository.NewVehicleEventRepository(db)
	eventService := service.NewVehicleEventService(eventRepo, nil, nil)
	h := NewVehicleEventHandler(eventService, nil)

	r := gin.New()
	r.GET("/vehicles/:id/events/stats", h.GetEventStats)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/1/events/stats", nil)
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401, got %d", rec.Code)
	}
}

func TestBasicAuthHeader(t *testing.T) {
	header := basicAuthHeader("test@example.com", "password")

	if header == "" {
		t.Fatal("expected auth header")
	}
}

func basicAuthHeader(email, password string) string {
	token := base64.StdEncoding.EncodeToString([]byte(email + ":" + password))
	return "Basic " + token
}

var _ = context.Background
var _ = time.Now
var _ = middleware.CurrentUser
