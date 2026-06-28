package service

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"net/mail"
	"strings"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrEmailTaken         = errors.New("email already registered")
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrInvalidEmail       = errors.New("invalid email")
	ErrWeakPassword       = errors.New("password must be at least 8 characters")
)

type AuthService struct {
	users      *repository.UserRepository
	bcryptCost int
}

func NewAuthService(users *repository.UserRepository, bcryptCost int) *AuthService {
	if bcryptCost < bcrypt.MinCost || bcryptCost > bcrypt.MaxCost {
		bcryptCost = bcrypt.DefaultCost
	}

	return &AuthService{
		users:      users,
		bcryptCost: bcryptCost,
	}
}

func (s *AuthService) Register(ctx context.Context, email, password, firstName, lastName string) (domain.User, error) {
	normalizedEmail, err := normalizeEmail(email)
	if err != nil {
		return domain.User{}, err
	}

	if err := validatePassword(password); err != nil {
		return domain.User{}, err
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), s.bcryptCost)
	if err != nil {
		return domain.User{}, fmt.Errorf("generate password hash: %w", err)
	}

	user, err := s.users.Create(ctx, normalizedEmail, string(hash), strings.TrimSpace(firstName), strings.TrimSpace(lastName))
	if errors.Is(err, repository.ErrConflict) {
		return domain.User{}, ErrEmailTaken
	}
	if err != nil {
		return domain.User{}, fmt.Errorf("create user: %w", err)
	}

	return user, nil
}

func (s *AuthService) Login(ctx context.Context, email, password string) (domain.User, error) {
	return s.Authenticate(ctx, email, password)
}

func (s *AuthService) Authenticate(ctx context.Context, email, password string) (domain.User, error) {
	normalizedEmail, err := normalizeEmail(email)
	if err != nil {
		return domain.User{}, ErrInvalidCredentials
	}

	if strings.TrimSpace(password) == "" {
		return domain.User{}, ErrInvalidCredentials
	}

	user, err := s.users.FindByEmail(ctx, normalizedEmail)
	if errors.Is(err, repository.ErrNotFound) {
		return domain.User{}, ErrInvalidCredentials
	}
	if err != nil {
		return domain.User{}, fmt.Errorf("find user by email: %w", err)
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return domain.User{}, ErrInvalidCredentials
	}

	return user, nil
}

func BasicToken(email, password string) string {
	return base64.StdEncoding.EncodeToString([]byte(email + ":" + password))
}

func normalizeEmail(email string) (string, error) {
	normalized := strings.ToLower(strings.TrimSpace(email))
	if normalized == "" {
		return "", ErrInvalidEmail
	}

	address, err := mail.ParseAddress(normalized)
	if err != nil || address.Address != normalized {
		return "", ErrInvalidEmail
	}

	return normalized, nil
}

func validatePassword(password string) error {
	if len(strings.TrimSpace(password)) < 8 {
		return ErrWeakPassword
	}

	return nil
}
