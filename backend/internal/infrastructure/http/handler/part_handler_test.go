package handler

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestPartHandler_ListByVehicle_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPartHandler(nil, nil)
	r := gin.New()
	r.GET("/vehicles/:id/parts", h.ListByVehicle)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/1/parts", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestPartHandler_ListByVehicle_InvalidID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPartHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.GET("/vehicles/:id/parts", h.ListByVehicle)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/abc/parts", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestPartHandler_CreatePart_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPartHandler(nil, nil)
	r := gin.New()
	r.POST("/vehicles/:id/parts", h.CreatePart)

	req := httptest.NewRequest(http.MethodPost, "/vehicles/1/parts", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestPartHandler_CreatePart_InvalidBody(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPartHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.POST("/vehicles/:id/parts", h.CreatePart)

	req := httptest.NewRequest(http.MethodPost, "/vehicles/1/parts", bytes.NewBufferString("bad"))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestPartHandler_CreatePart_InvalidDate(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPartHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.POST("/vehicles/:id/parts", h.CreatePart)

	body := `{"name":"Oil","last_service_date":"not-a-date"}`
	req := httptest.NewRequest(http.MethodPost, "/vehicles/1/parts", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestPartHandler_DeletePart_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPartHandler(nil, nil)
	r := gin.New()
	r.DELETE("/vehicles/:id/parts/:partId", h.DeletePart)

	req := httptest.NewRequest(http.MethodDelete, "/vehicles/1/parts/1", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestPartHandler_DeletePart_InvalidPartID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPartHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.DELETE("/vehicles/:id/parts/:partId", h.DeletePart)

	req := httptest.NewRequest(http.MethodDelete, "/vehicles/1/parts/abc", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestPartHandler_DeletePart_ZeroPartID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPartHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.DELETE("/vehicles/:id/parts/:partId", h.DeletePart)

	req := httptest.NewRequest(http.MethodDelete, "/vehicles/1/parts/0", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestParseTime(t *testing.T) {
	_, err := parseTime("2026-01-15T00:00:00Z")
	if err != nil {
		t.Fatalf("expected valid time, got %v", err)
	}

	_, err = parseTime("not-a-date")
	if err == nil {
		t.Fatal("expected error for invalid date")
	}
}
