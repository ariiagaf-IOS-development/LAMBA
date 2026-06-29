package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

type ChatRepository struct {
	db *sql.DB
}

type ChatMessageFilter struct {
	Limit  int
	Offset int
}

func NewChatRepository(db *sql.DB) *ChatRepository {
	return &ChatRepository{db: db}
}

func (r *ChatRepository) CreateForUser(
	ctx context.Context,
	userID int64,
	msg domain.ChatMessage,
) (domain.ChatMessage, error) {
	created, err := scanChatMessage(r.db.QueryRowContext(ctx, `
		INSERT INTO chat_messages (user_id, vehicle_id, role, message)
		SELECT $2, $1, $3, $4
		WHERE EXISTS (
			SELECT 1
			FROM vehicles
			WHERE id = $1 AND user_id = $2
		)
		RETURNING id, user_id, vehicle_id, role, message, created_at
	`, msg.VehicleID, userID, msg.Role, msg.Message))
	if errors.Is(err, sql.ErrNoRows) {
		return domain.ChatMessage{}, ErrNotFound
	}
	if err != nil {
		return domain.ChatMessage{}, fmt.Errorf("create chat message: %w", err)
	}

	return created, nil
}

func (r *ChatRepository) ListByVehicleForUser(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	filter ChatMessageFilter,
) ([]domain.ChatMessage, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT
			cm.id,
			cm.user_id,
			cm.vehicle_id,
			cm.role,
			cm.message,
			cm.created_at
		FROM chat_messages cm
		JOIN vehicles v ON v.id = cm.vehicle_id
		WHERE cm.vehicle_id = $1 AND v.user_id = $2
		ORDER BY cm.created_at ASC, cm.id ASC
		LIMIT $3 OFFSET $4
	`, vehicleID, userID, filter.Limit, filter.Offset)
	if err != nil {
		return nil, fmt.Errorf("list chat messages: %w", err)
	}
	defer rows.Close()

	messages := make([]domain.ChatMessage, 0)
	for rows.Next() {
		msg, err := scanChatMessage(rows)
		if err != nil {
			return nil, fmt.Errorf("scan chat message: %w", err)
		}

		messages = append(messages, msg)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate chat messages: %w", err)
	}

	if len(messages) == 0 {
		exists, err := r.vehicleBelongsToUser(ctx, userID, vehicleID)
		if err != nil {
			return nil, err
		}
		if !exists {
			return nil, ErrNotFound
		}
	}

	return messages, nil
}

func (r *ChatRepository) GetRecentByVehicleForUser(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	limit int,
) ([]domain.ChatMessage, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, user_id, vehicle_id, role, message, created_at
		FROM (
			SELECT
				cm.id,
				cm.user_id,
				cm.vehicle_id,
				cm.role,
				cm.message,
				cm.created_at
			FROM chat_messages cm
			JOIN vehicles v ON v.id = cm.vehicle_id
			WHERE cm.vehicle_id = $1 AND v.user_id = $2
			ORDER BY cm.created_at DESC, cm.id DESC
			LIMIT $3
		) sub
		ORDER BY created_at ASC, id ASC
	`, vehicleID, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("get recent chat messages: %w", err)
	}
	defer rows.Close()

	messages := make([]domain.ChatMessage, 0)
	for rows.Next() {
		msg, err := scanChatMessage(rows)
		if err != nil {
			return nil, fmt.Errorf("scan chat message: %w", err)
		}

		messages = append(messages, msg)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate chat messages: %w", err)
	}

	return messages, nil
}

func (r *ChatRepository) vehicleBelongsToUser(
	ctx context.Context,
	userID int64,
	vehicleID int64,
) (bool, error) {
	var exists bool

	err := r.db.QueryRowContext(ctx, `
		SELECT EXISTS (
			SELECT 1
			FROM vehicles
			WHERE id = $1 AND user_id = $2
		)
	`, vehicleID, userID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check vehicle ownership: %w", err)
	}

	return exists, nil
}

func scanChatMessage(scanner rowScanner) (domain.ChatMessage, error) {
	var msg domain.ChatMessage
	var userID sql.NullInt64

	err := scanner.Scan(
		&msg.ID,
		&userID,
		&msg.VehicleID,
		&msg.Role,
		&msg.Message,
		&msg.CreatedAt,
	)
	if err != nil {
		return domain.ChatMessage{}, err
	}

	if userID.Valid {
		msg.UserID = &userID.Int64
	}

	return msg, nil
}
