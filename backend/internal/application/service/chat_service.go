package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/application/provider"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
)

var (
	ErrChatMessageEmpty   = errors.New("chat message cannot be empty")
	ErrChatMessageTooLong = errors.New("chat message exceeds maximum length of 4000 characters")
	ErrChatAIUnavailable  = errors.New("AI service is unavailable")
	ErrChatLimitInvalid   = errors.New("chat limit must be positive")
	ErrChatOffsetInvalid  = errors.New("chat offset cannot be negative")
)

const (
	maxChatMessageLength = 4000
	maxToolCallRounds    = 5
	chatContextEvents    = 10
	chatContextMessages  = 20
	DefaultChatLimit     = 20
	MaxChatLimit         = 100
)

type ChatService struct {
	chat        *repository.ChatRepository
	vehicles    *repository.VehicleRepository
	events      *repository.VehicleEventRepository
	parts       *repository.PartRepository
	predictions *PredictionService
	aiProvider  provider.AIChatProvider
	tools       *ToolDispatcher
	log         *slog.Logger
}

func NewChatService(
	chat *repository.ChatRepository,
	vehicles *repository.VehicleRepository,
	events *repository.VehicleEventRepository,
	parts *repository.PartRepository,
	predictions *PredictionService,
	aiProvider provider.AIChatProvider,
	tools *ToolDispatcher,
	log *slog.Logger,
) *ChatService {
	if log == nil {
		log = slog.Default()
	}

	return &ChatService{
		chat:        chat,
		vehicles:    vehicles,
		events:      events,
		parts:       parts,
		predictions: predictions,
		aiProvider:  aiProvider,
		tools:       tools,
		log:         log,
	}
}

type ListChatHistoryInput struct {
	Limit  int
	Offset int
}

func (s *ChatService) SendMessage(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	message string,
) (domain.ChatMessage, error) {
	message = strings.TrimSpace(message)
	if message == "" {
		return domain.ChatMessage{}, ErrChatMessageEmpty
	}
	if len([]rune(message)) > maxChatMessageLength {
		return domain.ChatMessage{}, ErrChatMessageTooLong
	}

	if s.aiProvider == nil {
		return domain.ChatMessage{}, ErrChatAIUnavailable
	}

	vehicle, err := s.vehicles.GetByIDForUser(ctx, userID, vehicleID)
	if err != nil {
		return domain.ChatMessage{}, err
	}

	_, err = s.chat.CreateForUser(ctx, userID, domain.ChatMessage{
		VehicleID: vehicleID,
		Role:      domain.ChatRoleUser,
		Message:   message,
	})
	if err != nil {
		return domain.ChatMessage{}, fmt.Errorf("save user message: %w", err)
	}

	vehicleEvents, _ := s.events.ListByVehicleForUser(ctx, userID, vehicleID, repository.VehicleEventFilter{
		Limit:  chatContextEvents,
		Offset: 0,
	})

	vehicleParts, _ := s.parts.ListByVehicleForUser(ctx, userID, vehicleID)

	predictions, _ := s.predictions.GetOrGenerate(ctx, userID, vehicleID)

	recentMessages, _ := s.chat.GetRecentByVehicleForUser(ctx, userID, vehicleID, chatContextMessages)

	var totalCost float64
	for _, e := range vehicleEvents {
		totalCost += e.Cost
	}

	messages := make([]provider.AIChatMessage, 0, len(recentMessages)+4)
	messages = append(messages, provider.AIChatMessage{
		Role:    "system",
		Content: buildSystemMessage(vehicle, totalCost),
	})
	messages = append(messages, provider.AIChatMessage{
		Role:    "user",
		Content: buildVehicleContextMessage(vehicle, vehicleEvents, vehicleParts, predictions),
	})

	for _, msg := range recentMessages {
		messages = append(messages, provider.AIChatMessage{
			Role:    string(msg.Role),
			Content: msg.Message,
		})
	}

	messages = append(messages, provider.AIChatMessage{
		Role:    "user",
		Content: buildUserMessage(message),
	})

	toolDefs := s.tools.ToolDefinitions()
	toolCtx := ToolContext{UserID: userID, VehicleID: vehicleID}

	aiResp, err := s.aiProvider.Chat(ctx, provider.AIChatRequest{
		Messages: messages,
		Tools:    toolDefs,
	})
	if err != nil {
		return domain.ChatMessage{}, fmt.Errorf("call ai service: %w", err)
	}

	for round := 0; round < maxToolCallRounds && len(aiResp.Message.ToolCalls) > 0; round++ {
		messages = append(messages, aiResp.Message)

		for _, tc := range aiResp.Message.ToolCalls {
			result, toolErr := s.tools.Dispatch(ctx, toolCtx, tc.Function.Name, tc.Function.Arguments)
			if toolErr != nil {
				result = fmt.Sprintf("Error: %s", toolErr.Error())
				s.log.WarnContext(ctx, "tool call failed",
					slog.String("tool", tc.Function.Name),
					slog.String("error", toolErr.Error()),
				)
			}

			messages = append(messages, provider.AIChatMessage{
				Role:       "tool",
				Content:    result,
				ToolCallID: tc.ID,
			})
		}

		aiResp, err = s.aiProvider.Chat(ctx, provider.AIChatRequest{
			Messages: messages,
			Tools:    toolDefs,
		})
		if err != nil {
			return domain.ChatMessage{}, fmt.Errorf("call ai service after tool execution: %w", err)
		}
	}

	assistantContent := aiResp.Message.Content
	if assistantContent == "" {
		assistantContent = "I could not generate a response. Please try again."
	}

	saved, err := s.chat.CreateForUser(ctx, userID, domain.ChatMessage{
		VehicleID: vehicleID,
		Role:      domain.ChatRoleAssistant,
		Message:   assistantContent,
	})
	if err != nil {
		return domain.ChatMessage{}, fmt.Errorf("save assistant message: %w", err)
	}

	return saved, nil
}

func (s *ChatService) ListHistory(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	input ListChatHistoryInput,
) ([]domain.ChatMessage, error) {
	limit := input.Limit
	if limit == 0 {
		limit = DefaultChatLimit
	}
	if limit < 0 {
		return nil, ErrChatLimitInvalid
	}
	if limit > MaxChatLimit {
		limit = MaxChatLimit
	}

	if input.Offset < 0 {
		return nil, ErrChatOffsetInvalid
	}

	return s.chat.ListByVehicleForUser(ctx, userID, vehicleID, repository.ChatMessageFilter{
		Limit:  limit,
		Offset: input.Offset,
	})
}
