package provider

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestDeepSeekChatProvider_Chat_Success(t *testing.T) {
	content := "Hello, I am your assistant."
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/chat/completions" {
			t.Fatalf("expected path /chat/completions, got %s", r.URL.Path)
		}
		if r.Header.Get("Content-Type") != "application/json" {
			t.Fatalf("expected Content-Type application/json, got %s", r.Header.Get("Content-Type"))
		}
		if r.Header.Get("Authorization") != "Bearer test-key" {
			t.Fatalf("expected Authorization Bearer test-key, got %s", r.Header.Get("Authorization"))
		}

		resp := deepseekResponse{
			Choices: []deepseekChoice{
				{Message: deepseekMessage{Role: "assistant", Content: &content}},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	p := NewDeepSeekChatProvider(server.URL, "test-key")
	result, err := p.Chat(context.Background(), AIChatRequest{
		Messages: []AIChatMessage{{Role: "user", Content: "Hello"}},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.Message.Content != content {
		t.Fatalf("expected content %q, got %q", content, result.Message.Content)
	}
	if result.Message.Role != "assistant" {
		t.Fatalf("expected role assistant, got %s", result.Message.Role)
	}
}

func TestDeepSeekChatProvider_Chat_WithToolCalls(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := deepseekResponse{
			Choices: []deepseekChoice{
				{Message: deepseekMessage{
					Role: "assistant",
					ToolCalls: []AIToolCall{
						{
							ID:   "call_1",
							Type: "function",
							Function: AIFunctionCall{
								Name:      "get_vehicle_profile",
								Arguments: "{}",
							},
						},
					},
				}},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	p := NewDeepSeekChatProvider(server.URL, "")
	result, err := p.Chat(context.Background(), AIChatRequest{
		Messages: []AIChatMessage{{Role: "user", Content: "get my car info"}},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(result.Message.ToolCalls) != 1 {
		t.Fatalf("expected 1 tool call, got %d", len(result.Message.ToolCalls))
	}
	if result.Message.ToolCalls[0].Function.Name != "get_vehicle_profile" {
		t.Fatalf("expected tool name get_vehicle_profile, got %s", result.Message.ToolCalls[0].Function.Name)
	}
}

func TestDeepSeekChatProvider_Chat_NilContent(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := deepseekResponse{
			Choices: []deepseekChoice{
				{Message: deepseekMessage{Role: "assistant", Content: nil}},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	p := NewDeepSeekChatProvider(server.URL, "")
	result, err := p.Chat(context.Background(), AIChatRequest{
		Messages: []AIChatMessage{{Role: "user", Content: "Hello"}},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.Message.Content != "" {
		t.Fatalf("expected empty content, got %q", result.Message.Content)
	}
}

func TestDeepSeekChatProvider_Chat_NoChoices(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		resp := deepseekResponse{Choices: []deepseekChoice{}}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	p := NewDeepSeekChatProvider(server.URL, "")
	_, err := p.Chat(context.Background(), AIChatRequest{
		Messages: []AIChatMessage{{Role: "user", Content: "Hello"}},
	})
	if err == nil {
		t.Fatal("expected error for no choices")
	}
}

func TestDeepSeekChatProvider_Chat_ServerError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("internal error"))
	}))
	defer server.Close()

	p := NewDeepSeekChatProvider(server.URL, "")
	_, err := p.Chat(context.Background(), AIChatRequest{
		Messages: []AIChatMessage{{Role: "user", Content: "Hello"}},
	})
	if err == nil {
		t.Fatal("expected error for server error")
	}
}

func TestDeepSeekChatProvider_Chat_InvalidJSON(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("not json"))
	}))
	defer server.Close()

	p := NewDeepSeekChatProvider(server.URL, "")
	_, err := p.Chat(context.Background(), AIChatRequest{
		Messages: []AIChatMessage{{Role: "user", Content: "Hello"}},
	})
	if err == nil {
		t.Fatal("expected error for invalid JSON")
	}
}

func TestDeepSeekChatProvider_Chat_TrailingSlashURL(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/chat/completions" {
			t.Fatalf("expected path /chat/completions, got %s", r.URL.Path)
		}
		content := "ok"
		resp := deepseekResponse{
			Choices: []deepseekChoice{
				{Message: deepseekMessage{Role: "assistant", Content: &content}},
			},
		}
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	p := NewDeepSeekChatProvider(server.URL+"/", "")
	_, err := p.Chat(context.Background(), AIChatRequest{
		Messages: []AIChatMessage{{Role: "user", Content: "Hello"}},
	})
	if err != nil {
		t.Fatalf("expected no error with trailing slash, got %v", err)
	}
}

func TestDeepSeekChatProvider_Chat_NoAPIKey(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "" {
			t.Fatal("expected no Authorization header when API key is empty")
		}
		content := "ok"
		resp := deepseekResponse{
			Choices: []deepseekChoice{
				{Message: deepseekMessage{Role: "assistant", Content: &content}},
			},
		}
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	p := NewDeepSeekChatProvider(server.URL, "")
	_, err := p.Chat(context.Background(), AIChatRequest{
		Messages: []AIChatMessage{{Role: "user", Content: "Hello"}},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
}
