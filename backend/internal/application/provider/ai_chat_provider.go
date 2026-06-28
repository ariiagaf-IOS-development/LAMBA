package provider

import "context"

type AIChatProvider interface {
	Chat(ctx context.Context, request AIChatRequest) (AIChatResponse, error)
}

type AIChatMessage struct {
	Role       string       `json:"role"`
	Content    string       `json:"content,omitempty"`
	ToolCalls  []AIToolCall `json:"tool_calls,omitempty"`
	ToolCallID string       `json:"tool_call_id,omitempty"`
}

type AIToolCall struct {
	ID       string         `json:"id"`
	Type     string         `json:"type"`
	Function AIFunctionCall `json:"function"`
}

type AIFunctionCall struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"`
}

type AIToolDefinition struct {
	Type     string           `json:"type"`
	Function AIFunctionSchema `json:"function"`
}

type AIFunctionSchema struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Parameters  map[string]any `json:"parameters"`
}

type AIChatRequest struct {
	Messages []AIChatMessage    `json:"messages"`
	Tools    []AIToolDefinition `json:"tools,omitempty"`
}

type AIChatResponse struct {
	Message AIChatMessage `json:"message"`
}
