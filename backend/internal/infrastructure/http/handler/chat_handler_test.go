package handler

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestChatHandler_SendMessage_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewChatHandler(nil, nil)
	r := gin.New()
	r.POST("/vehicles/:id/chat", h.SendMessage)

	req := httptest.NewRequest(http.MethodPost, "/vehicles/1/chat", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestChatHandler_SendMessage_InvalidID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewChatHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.POST("/vehicles/:id/chat", h.SendMessage)

	req := httptest.NewRequest(http.MethodPost, "/vehicles/abc/chat", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestChatHandler_SendMessage_InvalidBody(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewChatHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.POST("/vehicles/:id/chat", h.SendMessage)

	req := httptest.NewRequest(http.MethodPost, "/vehicles/1/chat", bytes.NewBufferString("bad"))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestChatHandler_GetHistory_Unauthorized(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewChatHandler(nil, nil)
	r := gin.New()
	r.GET("/vehicles/:id/chat/history", h.GetHistory)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/1/chat/history", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestChatHandler_GetHistory_InvalidID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewChatHandler(nil, nil)
	r := gin.New()
	r.Use(setTestUser())
	r.GET("/vehicles/:id/chat/history", h.GetHistory)

	req := httptest.NewRequest(http.MethodGet, "/vehicles/abc/chat/history", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestParseChatHistoryQuery_Valid(t *testing.T) {
	gin.SetMode(gin.TestMode)
	req := httptest.NewRequest(http.MethodGet, "/chat?limit=10&offset=5", nil)
	rec := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(rec)
	c.Request = req

	input, ok := parseChatHistoryQuery(c)
	if !ok {
		t.Fatal("expected query to be parsed")
	}
	if input.Limit != 10 {
		t.Fatalf("expected limit 10, got %d", input.Limit)
	}
	if input.Offset != 5 {
		t.Fatalf("expected offset 5, got %d", input.Offset)
	}
}

func TestParseChatHistoryQuery_InvalidLimit(t *testing.T) {
	gin.SetMode(gin.TestMode)
	req := httptest.NewRequest(http.MethodGet, "/chat?limit=abc", nil)
	rec := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(rec)
	c.Request = req

	_, ok := parseChatHistoryQuery(c)
	if ok {
		t.Fatal("expected parsing to fail")
	}
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestParseChatHistoryQuery_InvalidOffset(t *testing.T) {
	gin.SetMode(gin.TestMode)
	req := httptest.NewRequest(http.MethodGet, "/chat?offset=abc", nil)
	rec := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(rec)
	c.Request = req

	_, ok := parseChatHistoryQuery(c)
	if ok {
		t.Fatal("expected parsing to fail")
	}
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestParseChatHistoryQuery_Defaults(t *testing.T) {
	gin.SetMode(gin.TestMode)
	req := httptest.NewRequest(http.MethodGet, "/chat", nil)
	rec := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(rec)
	c.Request = req

	input, ok := parseChatHistoryQuery(c)
	if !ok {
		t.Fatal("expected query to be parsed")
	}
	if input.Limit != 0 {
		t.Fatalf("expected default limit 0, got %d", input.Limit)
	}
	if input.Offset != 0 {
		t.Fatalf("expected default offset 0, got %d", input.Offset)
	}
}
