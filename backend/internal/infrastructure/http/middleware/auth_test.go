package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

func TestCurrentUser_NoUserInContext(t *testing.T) {
	gin.SetMode(gin.TestMode)
	c, _ := gin.CreateTestContext(httptest.NewRecorder())

	user, ok := CurrentUser(c)
	if ok {
		t.Fatal("expected no user in context")
	}
	if user.ID != 0 {
		t.Fatalf("expected zero user, got %+v", user)
	}
}

func TestCurrentUser_UserInContext(t *testing.T) {
	gin.SetMode(gin.TestMode)
	c, _ := gin.CreateTestContext(httptest.NewRecorder())
	c.Set(UserContextKey, domain.User{
		ID:    1,
		Email: "test@example.com",
	})

	user, ok := CurrentUser(c)
	if !ok {
		t.Fatal("expected user in context")
	}
	if user.ID != 1 {
		t.Fatalf("expected user ID 1, got %d", user.ID)
	}
	if user.Email != "test@example.com" {
		t.Fatalf("expected email test@example.com, got %s", user.Email)
	}
}

func TestCurrentUser_WrongTypeInContext(t *testing.T) {
	gin.SetMode(gin.TestMode)
	c, _ := gin.CreateTestContext(httptest.NewRecorder())
	c.Set(UserContextKey, "not a user")

	_, ok := CurrentUser(c)
	if ok {
		t.Fatal("expected no user when context has wrong type")
	}
}

func TestBasicAuth_NoCredentials(t *testing.T) {
	gin.SetMode(gin.TestMode)

	r := gin.New()
	r.Use(BasicAuth(nil))
	r.GET("/test", func(c *gin.Context) {
		c.Status(http.StatusOK)
	})

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}
