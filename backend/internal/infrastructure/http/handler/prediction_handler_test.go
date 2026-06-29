package handler

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestPredictionHandler_GetByVehicle_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPredictionHandler(nil, nil)
	r := gin.New()
	r.GET("/vehicles/:id/predictions", h.GetByVehicle)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/1/predictions", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestPredictionHandler_GetByVehicle_InvalidID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPredictionHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.GET("/vehicles/:id/predictions", h.GetByVehicle)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/abc/predictions", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestPredictionHandler_GetByVehicle_ZeroID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPredictionHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.GET("/vehicles/:id/predictions", h.GetByVehicle)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/0/predictions", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestPredictionHandler_RefreshPredictions_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPredictionHandler(nil, nil)
	r := gin.New()
	r.POST("/vehicles/:id/predictions/refresh", h.RefreshPredictions)

	req := httptest.NewRequest(http.MethodPost, "/vehicles/1/predictions/refresh", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestPredictionHandler_RefreshPredictions_InvalidID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPredictionHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.POST("/vehicles/:id/predictions/refresh", h.RefreshPredictions)

	req := httptest.NewRequest(http.MethodPost, "/vehicles/abc/predictions/refresh", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestPredictionHandler_PushPredictions_InvalidID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPredictionHandler(nil, nil)
	r := gin.New()
	r.POST("/api/internal/vehicles/:id/predictions", h.PushPredictions)

	req := httptest.NewRequest(http.MethodPost, "/api/internal/vehicles/abc/predictions", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestPredictionHandler_PushPredictions_InvalidBody(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewPredictionHandler(nil, nil)
	r := gin.New()
	r.POST("/api/internal/vehicles/:id/predictions", h.PushPredictions)

	req := httptest.NewRequest(http.MethodPost, "/api/internal/vehicles/1/predictions", bytes.NewBufferString("bad"))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}
