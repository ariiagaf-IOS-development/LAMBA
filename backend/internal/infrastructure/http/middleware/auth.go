package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/application/service"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

const UserContextKey = "authenticated_user"

func BasicAuth(auth *service.AuthService) gin.HandlerFunc {
	return func(c *gin.Context) {
		email, password, ok := c.Request.BasicAuth()
		if !ok {
			abortUnauthorized(c)
			return
		}

		user, err := auth.Authenticate(c.Request.Context(), email, password)
		if err != nil {
			abortUnauthorized(c)
			return
		}

		c.Set(UserContextKey, user)
		c.Next()
	}
}

func CurrentUser(c *gin.Context) (domain.User, bool) {
	value, exists := c.Get(UserContextKey)
	if !exists {
		return domain.User{}, false
	}

	user, ok := value.(domain.User)
	return user, ok
}

func abortUnauthorized(c *gin.Context) {
	c.Header("WWW-Authenticate", `Basic realm="lamba-api"`)
	c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "authentication required"})
}
