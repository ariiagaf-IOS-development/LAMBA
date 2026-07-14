package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5/pgconn"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

const postgresUniqueViolationCode = "23505"

type VehicleRepository struct {
	db *sql.DB
}

// VIN uses NullableStringUpdate because PATCH requests must distinguish between "not provided" and "clear value"
type NullableStringUpdate struct {
	Set   bool
	Value *string
}

type VehicleUpdate struct {
	Brand        *string
	Model        *string
	Year         *int
	VIN          NullableStringUpdate
	MileageKM    *int
	FuelType     NullableStringUpdate
	Transmission NullableStringUpdate
	UsageType    NullableStringUpdate
}

func NewVehicleRepository(db *sql.DB) *VehicleRepository {
	return &VehicleRepository{db: db}
}

func (r *VehicleRepository) Create(ctx context.Context, vehicle domain.Vehicle) (domain.Vehicle, error) {
	created, err := scanVehicle(r.db.QueryRowContext(ctx, `
		INSERT INTO vehicles (user_id, brand, model, year, vin, mileage_km, fuel_type, transmission, usage_type)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id, user_id, brand, model, year, vin, mileage_km, fuel_type, transmission, usage_type, created_at, updated_at
	`, vehicle.UserID, vehicle.Brand, vehicle.Model, vehicle.Year, vehicle.VIN, vehicle.MileageKM,
		vehicle.FuelType, vehicle.Transmission, vehicle.UsageType))
	if err != nil {
		if isUniqueViolation(err) {
			return domain.Vehicle{}, ErrConflict
		}

		return domain.Vehicle{}, fmt.Errorf("create vehicle: %w", err)
	}

	return created, nil
}

func (r *VehicleRepository) ListByUser(ctx context.Context, userID int64) ([]domain.Vehicle, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, user_id, brand, model, year, vin, mileage_km, fuel_type, transmission, usage_type, created_at, updated_at
		FROM vehicles
		WHERE user_id = $1
		ORDER BY id
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("list vehicles by user: %w", err)
	}
	defer rows.Close()

	vehicles := make([]domain.Vehicle, 0)
	for rows.Next() {
		vehicle, err := scanVehicle(rows)
		if err != nil {
			return nil, fmt.Errorf("scan vehicle: %w", err)
		}
		vehicles = append(vehicles, vehicle)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate vehicles: %w", err)
	}

	return vehicles, nil
}

func (r *VehicleRepository) GetByID(ctx context.Context, id int64) (domain.Vehicle, error) {
	vehicle, err := scanVehicle(r.db.QueryRowContext(ctx, `
		SELECT id, user_id, brand, model, year, vin, mileage_km, fuel_type, transmission, usage_type, created_at, updated_at
		FROM vehicles
		WHERE id = $1
	`, id))
	if errors.Is(err, sql.ErrNoRows) {
		return domain.Vehicle{}, ErrNotFound
	}
	if err != nil {
		return domain.Vehicle{}, fmt.Errorf("get vehicle by id: %w", err)
	}

	return vehicle, nil
}

func (r *VehicleRepository) GetByIDForUser(ctx context.Context, userID, id int64) (domain.Vehicle, error) {
	vehicle, err := scanVehicle(r.db.QueryRowContext(ctx, `
		SELECT id, user_id, brand, model, year, vin, mileage_km, fuel_type, transmission, usage_type, created_at, updated_at
		FROM vehicles
		WHERE user_id = $1 AND id = $2
	`, userID, id))
	if errors.Is(err, sql.ErrNoRows) {
		return domain.Vehicle{}, ErrNotFound
	}
	if err != nil {
		return domain.Vehicle{}, fmt.Errorf("get vehicle by id for user: %w", err)
	}

	return vehicle, nil
}

func (r *VehicleRepository) Update(ctx context.Context, userID, id int64, update VehicleUpdate) (domain.Vehicle, error) {
	sets := make([]string, 0, 6)
	args := []any{userID, id}

	if update.Brand != nil {
		sets, args = appendSet(sets, args, "brand", *update.Brand)
	}
	if update.Model != nil {
		sets, args = appendSet(sets, args, "model", *update.Model)
	}
	if update.Year != nil {
		sets, args = appendSet(sets, args, "year", *update.Year)
	}
	if update.VIN.Set {
		sets, args = appendSet(sets, args, "vin", update.VIN.Value)
	}
	if update.MileageKM != nil {
		sets, args = appendSet(sets, args, "mileage_km", *update.MileageKM)
	}
	if update.FuelType.Set {
		sets, args = appendSet(sets, args, "fuel_type", update.FuelType.Value)
	}
	if update.Transmission.Set {
		sets, args = appendSet(sets, args, "transmission", update.Transmission.Value)
	}
	if update.UsageType.Set {
		sets, args = appendSet(sets, args, "usage_type", update.UsageType.Value)
	}

	if len(sets) == 0 {
		return r.GetByIDForUser(ctx, userID, id)
	}

	sets = append(sets, "updated_at = NOW()")

	query := fmt.Sprintf(`
		UPDATE vehicles
		SET %s
		WHERE user_id = $1 AND id = $2
		RETURNING id, user_id, brand, model, year, vin, mileage_km, fuel_type, transmission, usage_type, created_at, updated_at
	`, strings.Join(sets, ", "))

	vehicle, err := scanVehicle(r.db.QueryRowContext(ctx, query, args...))
	if errors.Is(err, sql.ErrNoRows) {
		return domain.Vehicle{}, ErrNotFound
	}
	if err != nil {
		if isUniqueViolation(err) {
			return domain.Vehicle{}, ErrConflict
		}

		return domain.Vehicle{}, fmt.Errorf("update vehicle: %w", err)
	}

	return vehicle, nil
}

func (r *VehicleRepository) Delete(ctx context.Context, userID, id int64) error {
	result, err := r.db.ExecContext(ctx, `
		DELETE FROM vehicles
		WHERE user_id = $1 AND id = $2
	`, userID, id)
	if err != nil {
		return fmt.Errorf("delete vehicle: %w", err)
	}

	count, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("get deleted vehicles count: %w", err)
	}
	if count == 0 {
		return ErrNotFound
	}

	return nil
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanVehicle(scanner rowScanner) (domain.Vehicle, error) {
	var vehicle domain.Vehicle
	var vin, fuelType, transmission, usageType sql.NullString

	err := scanner.Scan(
		&vehicle.ID,
		&vehicle.UserID,
		&vehicle.Brand,
		&vehicle.Model,
		&vehicle.Year,
		&vin,
		&vehicle.MileageKM,
		&fuelType,
		&transmission,
		&usageType,
		&vehicle.CreatedAt,
		&vehicle.UpdatedAt,
	)
	if err != nil {
		return domain.Vehicle{}, err
	}

	if vin.Valid {
		vehicle.VIN = &vin.String
	}
	if fuelType.Valid {
		vehicle.FuelType = &fuelType.String
	}
	if transmission.Valid {
		vehicle.Transmission = &transmission.String
	}
	if usageType.Valid {
		vehicle.UsageType = &usageType.String
	}

	return vehicle, nil
}

func appendSet(sets []string, args []any, column string, value any) ([]string, []any) {
	args = append(args, value)
	sets = append(sets, fmt.Sprintf("%s = $%d", column, len(args)))

	return sets, args
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == postgresUniqueViolationCode
}
