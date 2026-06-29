package domain

import "time"

type ChatRole string

const (
	ChatRoleUser      ChatRole = "user"
	ChatRoleAssistant ChatRole = "assistant"
	ChatRoleSystem    ChatRole = "system"
)

func (r ChatRole) IsValid() bool {
	switch r {
	case ChatRoleUser, ChatRoleAssistant, ChatRoleSystem:
		return true
	default:
		return false
	}
}

type ChatMessage struct {
	ID        int64     `json:"id"`
	UserID    *int64    `json:"user_id,omitempty"`
	VehicleID int64     `json:"vehicle_id"`
	Role      ChatRole  `json:"role"`
	Message   string    `json:"message"`
	CreatedAt time.Time `json:"created_at"`
}
