package handler

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestDashboardHandler_GetDashboard_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewDashboardHandler(nil, nil)
	r := gin.New()
	r.GET("/vehicles/:id/dashboard", h.GetDashboard)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/1/dashboard", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestDashboardHandler_GetDashboard_InvalidID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewDashboardHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.GET("/vehicles/:id/dashboard", h.GetDashboard)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/abc/dashboard", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestDashboardHandler_GetDashboard_ZeroID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewDashboardHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.GET("/vehicles/:id/dashboard", h.GetDashboard)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/0/dashboard", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}
