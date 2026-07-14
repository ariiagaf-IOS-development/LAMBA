package router

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gin-gonic/gin"
)

func TestHealthRoute(t *testing.T) {
	gin.SetMode(gin.TestMode)

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()

	New().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, rec.Code)
	}
}

func TestProtectedRoutesRequireAuth(t *testing.T) {
	gin.SetMode(gin.TestMode)

	db, _, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	r := New(Dependencies{
		DB: db,
	})

	tests := []struct {
		name   string
		method string
		path   string
	}{
		{
			name:   "list vehicles",
			method: http.MethodGet,
			path:   "/api/vehicles",
		},
		{
			name:   "list vehicle events",
			method: http.MethodGet,
			path:   "/api/vehicles/1/events",
		},
		{
			name:   "vehicle timeline",
			method: http.MethodGet,
			path:   "/api/vehicles/1/timeline",
		},
		{
			name:   "vehicle event stats",
			method: http.MethodGet,
			path:   "/api/vehicles/1/events/stats",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(tt.method, tt.path, nil)
			rec := httptest.NewRecorder()

			r.ServeHTTP(rec, req)

			if rec.Code != http.StatusUnauthorized {
				t.Fatalf("expected status %d, got %d", http.StatusUnauthorized, rec.Code)
			}
		})
	}
}

func TestEventStatsRouteExists(t *testing.T) {
	gin.SetMode(gin.TestMode)

	db, _, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	r := New(Dependencies{
		DB: db,
	})

	req := httptest.NewRequest(http.MethodGet, "/api/vehicles/1/events/stats", nil)
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code == http.StatusNotFound {
		t.Fatal("expected stats route to exist, got 404")
	}
}

func TestTimelineRouteExists(t *testing.T) {
	gin.SetMode(gin.TestMode)

	db, _, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	r := New(Dependencies{
		DB: db,
	})

	req := httptest.NewRequest(http.MethodGet, "/api/vehicles/1/timeline", nil)
	rec := httptest.NewRecorder()

	r.ServeHTTP(rec, req)

	if rec.Code == http.StatusNotFound {
		t.Fatal("expected timeline route to exist, got 404")
	}
}
