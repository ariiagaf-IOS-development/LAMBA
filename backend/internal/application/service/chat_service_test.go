package service

import (
	"strings"
	"testing"
)

func TestChatService_ListHistory_NegativeLimit(t *testing.T) {
	svc := &ChatService{}
	_, err := svc.ListHistory(nil, 1, 1, ListChatHistoryInput{Limit: -1})
	if err != ErrChatLimitInvalid {
		t.Fatalf("expected ErrChatLimitInvalid, got %v", err)
	}
}

func TestChatService_ListHistory_NegativeOffset(t *testing.T) {
	svc := &ChatService{}
	_, err := svc.ListHistory(nil, 1, 1, ListChatHistoryInput{Offset: -1})
	if err != ErrChatOffsetInvalid {
		t.Fatalf("expected ErrChatOffsetInvalid, got %v", err)
	}
}

func TestChatService_SendMessage_EmptyMessage(t *testing.T) {
	svc := &ChatService{}
	_, err := svc.SendMessage(nil, 1, 1, "   ")
	if err != ErrChatMessageEmpty {
		t.Fatalf("expected ErrChatMessageEmpty, got %v", err)
	}
}

func TestChatService_SendMessage_TooLongMessage(t *testing.T) {
	svc := &ChatService{}
	longMessage := strings.Repeat("a", maxChatMessageLength+1)
	_, err := svc.SendMessage(nil, 1, 1, longMessage)
	if err != ErrChatMessageTooLong {
		t.Fatalf("expected ErrChatMessageTooLong, got %v", err)
	}
}

func TestChatService_SendMessage_NoProvider(t *testing.T) {
	svc := &ChatService{}
	_, err := svc.SendMessage(nil, 1, 1, "hello")
	if err != ErrChatAIUnavailable {
		t.Fatalf("expected ErrChatAIUnavailable, got %v", err)
	}
}
