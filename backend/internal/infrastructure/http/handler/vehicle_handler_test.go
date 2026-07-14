package handler

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/http/middleware"
)

func TestVehicleHandler_CreateVehicle_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewVehicleHandler(nil, nil)
	r := gin.New()
	r.POST("/vehicles", h.CreateVehicle)

	req := httptest.NewRequest(http.MethodPost, "/vehicles", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestVehicleHandler_CreateVehicle_InvalidBody(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewVehicleHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.POST("/vehicles", h.CreateVehicle)

	req := httptest.NewRequest(http.MethodPost, "/vehicles", bytes.NewBufferString("bad"))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestVehicleHandler_ListVehicle_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewVehicleHandler(nil, nil)
	r := gin.New()
	r.GET("/vehicles", h.ListVehicle)

	req := httptest.NewRequest(http.MethodGet, "/vehicles", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestVehicleHandler_GetVehicle_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewVehicleHandler(nil, nil)
	r := gin.New()
	r.GET("/vehicles/:id", h.GetVehicle)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/1", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestVehicleHandler_GetVehicle_InvalidID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewVehicleHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.GET("/vehicles/:id", h.GetVehicle)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/abc", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestVehicleHandler_GetVehicle_NegativeID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewVehicleHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.GET("/vehicles/:id", h.GetVehicle)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/-1", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestVehicleHandler_UpdateVehicle_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewVehicleHandler(nil, nil)
	r := gin.New()
	r.PATCH("/vehicles/:id", h.UpdateVehicle)

	req := httptest.NewRequest(http.MethodPatch, "/vehicles/1", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestVehicleHandler_UpdateVehicle_InvalidBody(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewVehicleHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.PATCH("/vehicles/:id", h.UpdateVehicle)

	req := httptest.NewRequest(http.MethodPatch, "/vehicles/1", bytes.NewBufferString("bad"))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestVehicleHandler_DeleteVehicle_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewVehicleHandler(nil, nil)
	r := gin.New()
	r.DELETE("/vehicles/:id", h.DeleteVehicle)

	req := httptest.NewRequest(http.MethodDelete, "/vehicles/1", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestVehicleHandler_DeleteVehicle_InvalidID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewVehicleHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.DELETE("/vehicles/:id", h.DeleteVehicle)

	req := httptest.NewRequest(http.MethodDelete, "/vehicles/abc", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestVehicleIDParam_Zero(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.GET("/vehicles/:id", func(c *gin.Context) {
		_, ok := vehicleIDParam(c)
		if ok {
			c.Status(http.StatusOK)
		}
	})

	req := httptest.NewRequest(http.MethodGet, "/vehicles/0", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for vehicle ID 0, got %d", rec.Code)
	}
}

func setTestUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Set(middleware.UserContextKey, domain.User{ID: 1, Email: "test@example.com"})
		c.Next()
	}
}
