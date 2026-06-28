package handler

import (
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/application/service"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/http/middleware"
)

type AuthHandler struct {
	auth *service.AuthService
	log  *slog.Logger
}

type authRequest struct {
	Email     string `json:"email" binding:"required" example:"driver@example.com"`
	Password  string `json:"password" binding:"required" example:"password123"`
	FirstName string `json:"first_name" example:"Ivan"`
	LastName  string `json:"last_name" example:"Petrov"`
}

type userResponse struct {
	ID        int64  `json:"id" example:"1"`
	Email     string `json:"email" example:"driver@example.com"`
	FirstName string `json:"first_name" example:"Ivan"`
	LastName  string `json:"last_name" example:"Petrov"`
	CreatedAt string `json:"created_at" example:"2026-06-12T12:00:00Z"`
}

type authResponse struct {
	User      userResponse `json:"user"`
	Token     string       `json:"token" example:"ZHJpdmVyQGV4YW1wbGUuY29tOnBhc3N3b3JkMTIz"`
	TokenType string       `json:"token_type" example:"Basic"`
}

func NewAuthHandler(auth *service.AuthService, log *slog.Logger) *AuthHandler {
	if log == nil {
		log = slog.Default()
	}

	return &AuthHandler{
		auth: auth,
		log:  log,
	}
}

// Register godoc
// @Summary Register a user
// @Description Creates a user account and returns an HTTP Basic token payload.
// @Tags auth
// @Accept json
// @Produce json
// @Param request body authRequest true "Registration credentials"
// @Success 201 {object} authResponse
// @Failure 400 {object} ErrorResponse
// @Failure 409 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/auth/register [post]
func (h *AuthHandler) Register(c *gin.Context) {
	var req authRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}

	user, err := h.auth.Register(c.Request.Context(), req.Email, req.Password, req.FirstName, req.LastName)
	if err != nil {
		h.handleAuthError(c, err)
		return
	}

	c.JSON(http.StatusCreated, newAuthResponse(user, req.Password))
}

// Login godoc
// @Summary Log in
// @Description Validates credentials and returns an HTTP Basic token payload.
// @Tags auth
// @Accept json
// @Produce json
// @Param request body authRequest true "Login credentials"
// @Success 200 {object} authResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/auth/login [post]
func (h *AuthHandler) Login(c *gin.Context) {
	var req authRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}

	user, err := h.auth.Login(c.Request.Context(), req.Email, req.Password)
	if err != nil {
		h.handleAuthError(c, err)
		return
	}

	c.JSON(http.StatusOK, newAuthResponse(user, req.Password))
}

// Me godoc
// @Summary Get current user
// @Description Returns the user authenticated by HTTP Basic credentials.
// @Tags auth
// @Produce json
// @Security BasicAuth
// @Success 200 {object} userResponse
// @Failure 401 {object} ErrorResponse
// @Router /api/me [get]
func (h *AuthHandler) Me(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	c.JSON(http.StatusOK, newUserResponse(user))
}

func (h *AuthHandler) handleAuthError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, service.ErrInvalidEmail):
		errorJSON(c, http.StatusBadRequest, "invalid email")
	case errors.Is(err, service.ErrWeakPassword):
		errorJSON(c, http.StatusBadRequest, "password must be at least 8 characters")
	case errors.Is(err, service.ErrEmailTaken):
		errorJSON(c, http.StatusConflict, "email already registered")
	case errors.Is(err, service.ErrInvalidCredentials):
		errorJSON(c, http.StatusUnauthorized, "invalid credentials")
	default:
		internalErrorJSON(c, h.log, "auth request failed", err)
	}
}

func newAuthResponse(user domain.User, password string) authResponse {
	return authResponse{
		User:      newUserResponse(user),
		Token:     service.BasicToken(user.Email, password),
		TokenType: "Basic",
	}
}

func newUserResponse(user domain.User) userResponse {
	return userResponse{
		ID:        user.ID,
		Email:     user.Email,
		FirstName: user.FirstName,
		LastName:  user.LastName,
		CreatedAt: user.CreatedAt.UTC().Format(time.RFC3339),
	}
}
