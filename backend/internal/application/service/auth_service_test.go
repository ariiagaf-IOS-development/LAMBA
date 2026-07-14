package service

import (
	"encoding/base64"
	"testing"
)

func TestNormalizeEmail(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    string
		wantErr error
	}{
		{"valid email", "test@example.com", "test@example.com", nil},
		{"uppercase email", "TEST@EXAMPLE.COM", "test@example.com", nil},
		{"email with spaces", "  test@example.com  ", "test@example.com", nil},
		{"empty email", "", "", ErrInvalidEmail},
		{"whitespace only", "   ", "", ErrInvalidEmail},
		{"no at sign", "testexample.com", "", ErrInvalidEmail},
		{"no domain", "test@", "", ErrInvalidEmail},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := normalizeEmail(tt.input)
			if err != tt.wantErr {
				t.Fatalf("expected error %v, got %v", tt.wantErr, err)
			}
			if got != tt.want {
				t.Fatalf("expected %q, got %q", tt.want, got)
			}
		})
	}
}

func TestValidatePassword(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		wantErr error
	}{
		{"valid password", "password123", nil},
		{"exactly 8 chars", "12345678", nil},
		{"too short", "1234567", ErrWeakPassword},
		{"empty", "", ErrWeakPassword},
		{"whitespace only", "       ", ErrWeakPassword},
		{"7 chars with spaces", " 1234567 ", ErrWeakPassword},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validatePassword(tt.input)
			if err != tt.wantErr {
				t.Fatalf("expected error %v, got %v", tt.wantErr, err)
			}
		})
	}
}

func TestBasicToken(t *testing.T) {
	token := BasicToken("test@example.com", "password123")
	decoded, err := base64.StdEncoding.DecodeString(token)
	if err != nil {
		t.Fatalf("expected valid base64, got error: %v", err)
	}
	expected := "test@example.com:password123"
	if string(decoded) != expected {
		t.Fatalf("expected %q, got %q", expected, string(decoded))
	}
}

func TestNewAuthService_BcryptCostBounds(t *testing.T) {
	svc := NewAuthService(nil, 0)
	if svc.bcryptCost < 4 || svc.bcryptCost > 31 {
		t.Fatalf("expected bcrypt cost within bounds, got %d", svc.bcryptCost)
	}

	svc = NewAuthService(nil, 100)
	if svc.bcryptCost < 4 || svc.bcryptCost > 31 {
		t.Fatalf("expected bcrypt cost within bounds, got %d", svc.bcryptCost)
	}

	svc = NewAuthService(nil, 10)
	if svc.bcryptCost != 10 {
		t.Fatalf("expected bcrypt cost 10, got %d", svc.bcryptCost)
	}
}
