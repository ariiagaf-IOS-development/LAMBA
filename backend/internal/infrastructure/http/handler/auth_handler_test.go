package handler

import (
	"bytes"
	"encoding/json"
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
	"golang.org/x/crypto/bcrypt"
)

func TestAuthHandler_Register_InvalidBody(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewAuthHandler(nil, nil)
	r := gin.New()
	r.POST("/register", h.Register)

	req := httptest.NewRequest(http.MethodPost, "/register", bytes.NewBufferString("invalid"))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestAuthHandler_Login_InvalidBody(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewAuthHandler(nil, nil)
	r := gin.New()
	r.POST("/login", h.Login)

	req := httptest.NewRequest(http.MethodPost, "/login", bytes.NewBufferString("invalid"))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestAuthHandler_Me_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewAuthHandler(nil, nil)
	r := gin.New()
	r.GET("/me", h.Me)

	req := httptest.NewRequest(http.MethodGet, "/me", nil)
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestAuthHandler_Me_Authenticated(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewAuthHandler(nil, nil)
	r := gin.New()
	r.Use(func(c *gin.Context) {
		c.Set(middleware.UserContextKey, domain.User{
			ID:        1,
			Email:     "test@example.com",
			FirstName: "Test",
			LastName:  "User",
			CreatedAt: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		})
		c.Next()
	})
	r.GET("/me", h.Me)

	req := httptest.NewRequest(http.MethodGet, "/me", nil)
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var resp userResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if resp.Email != "test@example.com" {
		t.Fatalf("expected email test@example.com, got %s", resp.Email)
	}
}

func TestAuthHandler_Register_WeakPassword(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, _, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	userRepo := repository.NewUserRepository(db)
	authService := service.NewAuthService(userRepo, bcrypt.MinCost)
	h := NewAuthHandler(authService, nil)
	r := gin.New()
	r.POST("/register", h.Register)

	body, _ := json.Marshal(authRequest{
		Email:    "test@example.com",
		Password: "short",
	})
	req := httptest.NewRequest(http.MethodPost, "/register", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestAuthHandler_Register_InvalidEmail(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, _, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	userRepo := repository.NewUserRepository(db)
	authService := service.NewAuthService(userRepo, bcrypt.MinCost)
	h := NewAuthHandler(authService, nil)
	r := gin.New()
	r.POST("/register", h.Register)

	body, _ := json.Marshal(authRequest{
		Email:    "not-an-email",
		Password: "password123",
	})
	req := httptest.NewRequest(http.MethodPost, "/register", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestNewUserResponse(t *testing.T) {
	user := domain.User{
		ID:        1,
		Email:     "test@example.com",
		FirstName: "Ivan",
		LastName:  "Petrov",
		CreatedAt: time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC),
	}
	resp := newUserResponse(user)
	if resp.ID != 1 {
		t.Fatalf("expected ID 1, got %d", resp.ID)
	}
	if resp.Email != "test@example.com" {
		t.Fatalf("expected email test@example.com, got %s", resp.Email)
	}
	if resp.FirstName != "Ivan" {
		t.Fatalf("expected first name Ivan, got %s", resp.FirstName)
	}
	if resp.CreatedAt != "2026-06-01T12:00:00Z" {
		t.Fatalf("expected RFC3339 date, got %s", resp.CreatedAt)
	}
}

func TestNewAuthResponse(t *testing.T) {
	user := domain.User{
		ID:        1,
		Email:     "test@example.com",
		FirstName: "Ivan",
		LastName:  "Petrov",
		CreatedAt: time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC),
	}
	resp := newAuthResponse(user, "password123")
	if resp.TokenType != "Basic" {
		t.Fatalf("expected token type Basic, got %s", resp.TokenType)
	}
	if resp.Token == "" {
		t.Fatal("expected non-empty token")
	}
	if resp.User.Email != "test@example.com" {
		t.Fatalf("expected email test@example.com, got %s", resp.User.Email)
	}
}
