package handler

import (
	"errors"
	"log/slog"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/application/service"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/http/middleware"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
)

type ChatHandler struct {
	chat *service.ChatService
	log  *slog.Logger
}

type chatRequest struct {
	Message string `json:"message" binding:"required" example:"Когда мне нужно менять масло?"`
}

type chatResponse struct {
	Message domain.ChatMessage `json:"message"`
}

type chatHistoryResponse struct {
	VehicleID int64                `json:"vehicle_id"`
	Messages  []domain.ChatMessage `json:"messages"`
	Limit     int                  `json:"limit"`
	Offset    int                  `json:"offset"`
	Count     int                  `json:"count"`
}

func NewChatHandler(chat *service.ChatService, log *slog.Logger) *ChatHandler {
	if log == nil {
		log = slog.Default()
	}

	return &ChatHandler{
		chat: chat,
		log:  log,
	}
}

// SendMessage godoc
// @Summary Send a chat message
// @Description Sends a message to the AI assistant in the context of a specific vehicle. Returns the AI-generated response.
// @Tags chat
// @Accept json
// @Produce json
// @Security BasicAuth
// @Param id path int true "Vehicle ID"
// @Param request body chatRequest true "Chat message"
// @Success 200 {object} chatResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Failure 503 {object} ErrorResponse
// @Router /api/vehicles/{id}/chat [post]
func (h *ChatHandler) SendMessage(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	vehicleID, ok := vehicleIDParam(c)
	if !ok {
		return
	}

	var req chatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		errorJSON(c, http.StatusBadRequest, "invalid request body")
		return
	}

	result, err := h.chat.SendMessage(c.Request.Context(), user.ID, vehicleID, req.Message)
	if err != nil {
		h.handleChatError(c, err)
		return
	}

	c.JSON(http.StatusOK, chatResponse{Message: result})
}

// GetHistory godoc
// @Summary Get chat history
// @Description Returns paginated chat message history for a vehicle in chronological order.
// @Tags chat
// @Produce json
// @Security BasicAuth
// @Param id path int true "Vehicle ID"
// @Param limit query int false "Limit (default 20, max 100)"
// @Param offset query int false "Offset (default 0)"
// @Success 200 {object} chatHistoryResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/vehicles/{id}/chat/history [get]
func (h *ChatHandler) GetHistory(c *gin.Context) {
	user, ok := middleware.CurrentUser(c)
	if !ok {
		errorJSON(c, http.StatusUnauthorized, "authentication required")
		return
	}

	vehicleID, ok := vehicleIDParam(c)
	if !ok {
		return
	}

	input, ok := parseChatHistoryQuery(c)
	if !ok {
		return
	}

	messages, err := h.chat.ListHistory(c.Request.Context(), user.ID, vehicleID, input)
	if err != nil {
		h.handleChatError(c, err)
		return
	}

	limit := input.Limit
	if limit == 0 {
		limit = service.DefaultChatLimit
	}
	if limit > service.MaxChatLimit {
		limit = service.MaxChatLimit
	}

	c.JSON(http.StatusOK, chatHistoryResponse{
		VehicleID: vehicleID,
		Messages:  messages,
		Limit:     limit,
		Offset:    input.Offset,
		Count:     len(messages),
	})
}

func parseChatHistoryQuery(c *gin.Context) (service.ListChatHistoryInput, bool) {
	var input service.ListChatHistoryInput

	if rawLimit := c.Query("limit"); rawLimit != "" {
		limit, err := strconv.Atoi(rawLimit)
		if err != nil {
			errorJSON(c, http.StatusBadRequest, "invalid limit")
			return service.ListChatHistoryInput{}, false
		}
		input.Limit = limit
	}

	if rawOffset := c.Query("offset"); rawOffset != "" {
		offset, err := strconv.Atoi(rawOffset)
		if err != nil {
			errorJSON(c, http.StatusBadRequest, "invalid offset")
			return service.ListChatHistoryInput{}, false
		}
		input.Offset = offset
	}

	return input, true
}

func (h *ChatHandler) handleChatError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, service.ErrChatMessageEmpty),
		errors.Is(err, service.ErrChatMessageTooLong),
		errors.Is(err, service.ErrChatLimitInvalid),
		errors.Is(err, service.ErrChatOffsetInvalid):
		errorJSON(c, http.StatusBadRequest, err.Error())
	case errors.Is(err, repository.ErrNotFound):
		errorJSON(c, http.StatusNotFound, "vehicle not found")
	case errors.Is(err, service.ErrChatAIUnavailable):
		errorJSON(c, http.StatusServiceUnavailable, "AI service is temporarily unavailable")
	default:
		internalErrorJSON(c, h.log, "chat request failed", err)
	}
}
