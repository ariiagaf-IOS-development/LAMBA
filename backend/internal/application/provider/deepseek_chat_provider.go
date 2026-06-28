package provider

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

const aiChatRequestTimeout = 60 * time.Second

type DeepSeekChatProvider struct {
	apiURL string
	apiKey string
	client *http.Client
}

func NewDeepSeekChatProvider(apiURL, apiKey string) *DeepSeekChatProvider {
	return &DeepSeekChatProvider{
		apiURL: apiURL,
		apiKey: apiKey,
		client: &http.Client{
			Timeout: aiChatRequestTimeout,
		},
	}
}

type deepseekRequest struct {
	Messages []AIChatMessage    `json:"messages"`
	Tools    []AIToolDefinition `json:"tools,omitempty"`
}

type deepseekResponse struct {
	Choices []deepseekChoice `json:"choices"`
}

type deepseekChoice struct {
	Message deepseekMessage `json:"message"`
}

type deepseekMessage struct {
	Role      string       `json:"role"`
	Content   *string      `json:"content"`
	ToolCalls []AIToolCall `json:"tool_calls,omitempty"`
}

func (p *DeepSeekChatProvider) Chat(
	ctx context.Context,
	request AIChatRequest,
) (AIChatResponse, error) {
	reqBody := deepseekRequest{
		Messages: request.Messages,
		Tools:    request.Tools,
	}

	jsonBody, err := json.Marshal(reqBody)
	if err != nil {
		return AIChatResponse{}, fmt.Errorf("marshal ai chat request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.apiURL, bytes.NewReader(jsonBody))
	if err != nil {
		return AIChatResponse{}, fmt.Errorf("create ai chat request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if p.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+p.apiKey)
	}

	resp, err := p.client.Do(req)
	if err != nil {
		return AIChatResponse{}, fmt.Errorf("call ai service: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return AIChatResponse{}, fmt.Errorf("read ai response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return AIChatResponse{}, fmt.Errorf("ai service returned status %d: %s", resp.StatusCode, string(body))
	}

	var dsResp deepseekResponse
	if err := json.Unmarshal(body, &dsResp); err != nil {
		return AIChatResponse{}, fmt.Errorf("unmarshal ai response: %w", err)
	}

	if len(dsResp.Choices) == 0 {
		return AIChatResponse{}, fmt.Errorf("ai service returned no choices")
	}

	choice := dsResp.Choices[0]
	content := ""
	if choice.Message.Content != nil {
		content = *choice.Message.Content
	}

	return AIChatResponse{
		Message: AIChatMessage{
			Role:      choice.Message.Role,
			Content:   content,
			ToolCalls: choice.Message.ToolCalls,
		},
	}, nil
}
