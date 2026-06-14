package repository

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

type VehicleEventRepository struct {
	db *sql.DB
}

type VehicleEventUpdate struct {
	Type        *domain.EventType
	Title       *string
	Description NullableStringUpdate
	MileageKM   *int
	Cost        *float64
	EventDate   *time.Time
	Metadata    JSONBUpdate
}

type JSONBUpdate struct {
	Set   bool
	Value map[string]any
}

func NewVehicleEventRepository(db *sql.DB) *VehicleEventRepository {
	return &VehicleEventRepository{db: db}
}

func (r *VehicleEventRepository) CreateForUser(
	ctx context.Context,
	userID int64,
	event domain.VehicleEvent,
) (domain.VehicleEvent, error) {
	metadata, err := marshalJSONB(event.Metadata)
	if err != nil {
		return domain.VehicleEvent{}, err
	}
	created, err := scanVehicleEvent(r.db.QueryRowContext(ctx, `
		INSERT INTO vehicle_events (
			vehicle_id,
			type,
			title,
			description,
			mileage_km,
			cost,
			event_date,
			metadata
		)
		SELECT
			$1, $3, $4, $5, $6, $7, $8, $9
		WHERE EXISTS (
			SELECT 1
			FROM vehicles
			WHERE id = $1 AND user_id = $2
		)
		RETURNING
			id,
			vehicle_id,
			type,
			title,
			description,
			mileage_km,
			cost,
			event_date,
			metadata,
			created_at
	`, event.VehicleID,
		userID,
		event.Type,
		event.Title,
		event.Description,
		event.MileageKM,
		event.Cost,
		event.EventDate,
		metadata,
	))
	if errors.Is(err, sql.ErrNoRows) {
		return domain.VehicleEvent{}, ErrNotFound
	}
	if err != nil {
		return domain.VehicleEvent{}, fmt.Errorf("create vehicle event: %w", err)
	}

	return created, nil
}

func (r *VehicleEventRepository) ListByVehicleForUser(
	ctx context.Context,
	userID int64,
	vehicleID int64,
) ([]domain.VehicleEvent, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT
			ve.id,
			ve.vehicle_id,
			ve.type,
			ve.title,
			ve.description,
			ve.mileage_km,
			ve.cost,
			ve.event_date,
			ve.metadata,
			ve.created_at
		FROM vehicle_events ve
		JOIN vehicles v ON v.id = ve.vehicle_id
		WHERE ve.vehicle_id = $1 AND v.user_id = $2
		ORDER BY ve.event_date DESC, ve.id DESC
	`, vehicleID, userID)
	if err != nil {
		return nil, fmt.Errorf("list vehicle events: %w", err)
	}
	defer rows.Close()

	events := make([]domain.VehicleEvent, 0)
	for rows.Next() {
		event, err := scanVehicleEvent(rows)
		if err != nil {
			return nil, fmt.Errorf("scan vehicle event: %w", err)
		}

		events = append(events, event)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate vehicle events: %w", err)
	}

	if len(events) == 0 {
		exists, err := r.vehicleBelongsToUser(ctx, userID, vehicleID)
		if err != nil {
			return nil, err
		}
		if !exists {
			return nil, ErrNotFound
		}
	}

	return events, nil
}

func (r *VehicleEventRepository) UpdateForUser(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	eventID int64,
	update VehicleEventUpdate,
) (domain.VehicleEvent, error) {
	sets := make([]string, 0, 7)
	args := []any{userID, vehicleID, eventID}

	if update.Type != nil {
		sets, args = appendSet(sets, args, "type", *update.Type)
	}
	if update.Title != nil {
		sets, args = appendSet(sets, args, "title", *update.Title)
	}
	if update.Description.Set {
		sets, args = appendSet(sets, args, "description", update.Description.Value)
	}
	if update.MileageKM != nil {
		sets, args = appendSet(sets, args, "mileage_km", *update.MileageKM)
	}
	if update.Cost != nil {
		sets, args = appendSet(sets, args, "cost", *update.Cost)
	}
	if update.EventDate != nil {
		sets, args = appendSet(sets, args, "event_date", *update.EventDate)
	}
	if update.Metadata.Set {
		metadata, err := marshalJSONB(update.Metadata.Value)
		if err != nil {
			return domain.VehicleEvent{}, err
		}

		sets, args = appendSet(sets, args, "metadata", metadata)
	}

	if len(sets) == 0 {
		return r.GetByIDForUser(ctx, userID, vehicleID, eventID)
	}

	query := fmt.Sprintf(`
		UPDATE vehicle_events ve
		SET %s
		FROM vehicles v
		WHERE
			ve.vehicle_id = v.id
			AND v.user_id = $1
			AND ve.vehicle_id = $2
			AND ve.id = $3
		RETURNING
			ve.id,
			ve.vehicle_id,
			ve.type,
			ve.title,
			ve.description,
			ve.mileage_km,
			ve.cost,
			ve.event_date,
			ve.metadata,
			ve.created_at
	`, strings.Join(sets, ", "))

	event, err := scanVehicleEvent(r.db.QueryRowContext(ctx, query, args...))
	if errors.Is(err, sql.ErrNoRows) {
		return domain.VehicleEvent{}, ErrNotFound
	}
	if err != nil {
		return domain.VehicleEvent{}, fmt.Errorf("update vehicle event: %w", err)
	}

	return event, nil
}

func (r *VehicleEventRepository) DeleteForUser(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	eventID int64,
) error {
	result, err := r.db.ExecContext(ctx, `
		DELETE FROM vehicle_events ve
		USING vehicles v
		WHERE
			ve.vehicle_id = v.id
			AND v.user_id = $1
			AND ve.vehicle_id = $2
			AND ve.id = $3
	`, userID, vehicleID, eventID)
	if err != nil {
		return fmt.Errorf("delete vehicle event: %w", err)
	}

	count, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("get deleted vehicle events count: %w", err)
	}
	if count == 0 {
		return ErrNotFound
	}

	return nil
}

func (r *VehicleEventRepository) GetByIDForUser(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	eventID int64,
) (domain.VehicleEvent, error) {
	event, err := scanVehicleEvent(r.db.QueryRowContext(ctx, `
		SELECT
			ve.id,
			ve.vehicle_id,
			ve.type,
			ve.title,
			ve.description,
			ve.mileage_km,
			ve.cost,
			ve.event_date,
			ve.metadata,
			ve.created_at
		FROM vehicle_events ve
		JOIN vehicles v ON v.id = ve.vehicle_id
		WHERE
			v.user_id = $1
			AND ve.vehicle_id = $2
			AND ve.id = $3
	`, userID, vehicleID, eventID))
	if errors.Is(err, sql.ErrNoRows) {
		return domain.VehicleEvent{}, ErrNotFound
	}
	if err != nil {
		return domain.VehicleEvent{}, fmt.Errorf("get vehicle event: %w", err)
	}

	return event, nil
}

func (r *VehicleEventRepository) vehicleBelongsToUser(
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

func scanVehicleEvent(scanner rowScanner) (domain.VehicleEvent, error) {
	var event domain.VehicleEvent
	var description sql.NullString
	var metadata []byte

	err := scanner.Scan(
		&event.ID,
		&event.VehicleID,
		&event.Type,
		&event.Title,
		&description,
		&event.MileageKM,
		&event.Cost,
		&event.EventDate,
		&metadata,
		&event.CreatedAt,
	)
	if err != nil {
		return domain.VehicleEvent{}, err
	}

	if description.Valid {
		event.Description = &description.String
	}

	event.Metadata = map[string]any{}
	if len(metadata) > 0 {
		if err := json.Unmarshal(metadata, &event.Metadata); err != nil {
			return domain.VehicleEvent{}, fmt.Errorf("decode vehicle event metadata: %w", err)
		}
	}

	return event, nil
}

func marshalJSONB(value map[string]any) ([]byte, error) {
	if value == nil {
		value = map[string]any{}
	}

	data, err := json.Marshal(value)
	if err != nil {
		return nil, fmt.Errorf("marshal jsonb: %w", err)
	}

	return data, nil
}
