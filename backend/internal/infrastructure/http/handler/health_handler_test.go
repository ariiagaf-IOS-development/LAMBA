package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gin-gonic/gin"
)

func TestHealthHandler_NoDatabase(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewHealthHandler(nil)
	r := gin.New()
	r.GET("/health", h.CheckHealth)

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var resp HealthResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Status != "ok" {
		t.Fatalf("expected status ok, got %s", resp.Status)
	}
	if resp.Service != "lamba-api" {
		t.Fatalf("expected service lamba-api, got %s", resp.Service)
	}
	if resp.Checks["api"] != "ok" {
		t.Fatalf("expected api check ok, got %s", resp.Checks["api"])
	}
}

func TestHealthHandler_DatabaseOK(t *testing.T) {
	gin.SetMode(gin.TestMode)

	db, mock, err := sqlmock.New(sqlmock.MonitorPingsOption(true))
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	mock.ExpectPing()

	h := NewHealthHandler(db)
	r := gin.New()
	r.GET("/health", h.CheckHealth)

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var resp HealthResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Status != "ok" {
		t.Fatalf("expected status ok, got %s", resp.Status)
	}
	if resp.Checks["postgres"] != "ok" {
		t.Fatalf("expected postgres ok, got %s", resp.Checks["postgres"])
	}
}

func TestHealthHandler_DatabaseDown(t *testing.T) {
	gin.SetMode(gin.TestMode)

	db, _, err := sqlmock.New(sqlmock.MonitorPingsOption(true))
	if err != nil {
		t.Fatal(err)
	}
	db.Close()

	h := NewHealthHandler(db)
	r := gin.New()
	r.GET("/health", h.CheckHealth)

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", rec.Code)
	}

	var resp HealthResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Status != "degraded" {
		t.Fatalf("expected status degraded, got %s", resp.Status)
	}
	if resp.Checks["postgres"] != "unavailable" {
		t.Fatalf("expected postgres unavailable, got %s", resp.Checks["postgres"])
	}
}

func TestErrorJSON(t *testing.T) {
	gin.SetMode(gin.TestMode)
	rec := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(rec)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	errorJSON(c, http.StatusBadRequest, "test error")

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Error != "test error" {
		t.Fatalf("expected error message 'test error', got %s", resp.Error)
	}
}

func TestInternalErrorJSON(t *testing.T) {
	gin.SetMode(gin.TestMode)
	rec := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(rec)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	internalErrorJSON(c, nil, "something failed", http.ErrAbortHandler)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", rec.Code)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Error != "internal server error" {
		t.Fatalf("expected 'internal server error', got %s", resp.Error)
	}
}
