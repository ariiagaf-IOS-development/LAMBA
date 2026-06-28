package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

type PartRepository struct {
	db *sql.DB
}

type CreateVehiclePartInput struct {
	VehicleID            int64
	CatalogCode          *string
	Name                 string
	Category             *string
	InstalledAtMileageKM *int
	LastServiceMileageKM *int
	LastServiceDate      *time.Time
}

func NewPartRepository(db *sql.DB) *PartRepository {
	return &PartRepository{db: db}
}

func (r *PartRepository) ListCatalog(ctx context.Context) ([]domain.PartCatalogItem, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, code, name, category, default_lifetime_km, default_lifetime_days, created_at
		FROM parts_catalog
		ORDER BY category, name
	`)
	if err != nil {
		return nil, fmt.Errorf("list parts catalog: %w", err)
	}
	defer rows.Close()

	items := make([]domain.PartCatalogItem, 0)
	for rows.Next() {
		item, err := scanPartCatalogItem(rows)
		if err != nil {
			return nil, fmt.Errorf("scan part catalog item: %w", err)
		}
		items = append(items, item)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate parts catalog: %w", err)
	}

	return items, nil
}

func (r *PartRepository) ListByVehicleForUser(
	ctx context.Context,
	userID int64,
	vehicleID int64,
) ([]domain.VehiclePart, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT
			p.id,
			p.vehicle_id,
			p.catalog_code,
			p.name,
			p.category,
			p.installed_at_mileage_km,
			p.last_service_mileage_km,
			p.last_service_date,
			p.created_at,
			p.updated_at
		FROM parts p
		JOIN vehicles v ON v.id = p.vehicle_id
		WHERE p.vehicle_id = $1 AND v.user_id = $2
		ORDER BY p.id
	`, vehicleID, userID)
	if err != nil {
		return nil, fmt.Errorf("list vehicle parts: %w", err)
	}
	defer rows.Close()

	parts := make([]domain.VehiclePart, 0)
	for rows.Next() {
		part, err := scanVehiclePart(rows)
		if err != nil {
			return nil, fmt.Errorf("scan vehicle part: %w", err)
		}
		parts = append(parts, part)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate vehicle parts: %w", err)
	}

	if len(parts) == 0 {
		exists, err := r.vehicleBelongsToUser(ctx, userID, vehicleID)
		if err != nil {
			return nil, err
		}
		if !exists {
			return nil, ErrNotFound
		}
	}

	return parts, nil
}

func (r *PartRepository) CreateForUser(
	ctx context.Context,
	userID int64,
	input CreateVehiclePartInput,
) (domain.VehiclePart, error) {
	part, err := scanVehiclePart(r.db.QueryRowContext(ctx, `
		INSERT INTO parts (
			vehicle_id,
			catalog_code,
			name,
			category,
			installed_at_mileage_km,
			last_service_mileage_km,
			last_service_date
		)
		SELECT $1, $3, $4, $5, $6, $7, $8
		WHERE EXISTS (
			SELECT 1
			FROM vehicles
			WHERE id = $1 AND user_id = $2
		)
		RETURNING
			id,
			vehicle_id,
			catalog_code,
			name,
			category,
			installed_at_mileage_km,
			last_service_mileage_km,
			last_service_date,
			created_at,
			updated_at
	`, input.VehicleID,
		userID,
		input.CatalogCode,
		input.Name,
		input.Category,
		input.InstalledAtMileageKM,
		input.LastServiceMileageKM,
		input.LastServiceDate,
	))
	if errors.Is(err, sql.ErrNoRows) {
		return domain.VehiclePart{}, ErrNotFound
	}
	if err != nil {
		return domain.VehiclePart{}, fmt.Errorf("create vehicle part: %w", err)
	}

	return part, nil
}

func (r *PartRepository) UpsertServiceByCatalogCodeForUser(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	catalogCode string,
	serviceMileageKM int,
	serviceDate time.Time,
) (domain.VehiclePart, error) {
	part, err := scanVehiclePart(r.db.QueryRowContext(ctx, `
		INSERT INTO parts (
			vehicle_id,
			catalog_code,
			name,
			category,
			installed_at_mileage_km,
			last_service_mileage_km,
			last_service_date
		)
		SELECT
			$1,
			pc.code,
			pc.name,
			pc.category,
			$4,
			$4,
			$5
		FROM parts_catalog pc
		WHERE pc.code = $3
			AND EXISTS (
				SELECT 1
				FROM vehicles
				WHERE id = $1 AND user_id = $2
			)
		ON CONFLICT DO NOTHING
		RETURNING
			id,
			vehicle_id,
			catalog_code,
			name,
			category,
			installed_at_mileage_km,
			last_service_mileage_km,
			last_service_date,
			created_at,
			updated_at
	`, vehicleID, userID, catalogCode, serviceMileageKM, serviceDate))

	if errors.Is(err, sql.ErrNoRows) {
		return r.UpdateServiceByCatalogCodeForUser(ctx, userID, vehicleID, catalogCode, serviceMileageKM, serviceDate)
	}
	if err != nil {
		return domain.VehiclePart{}, fmt.Errorf("upsert vehicle part service: %w", err)
	}

	return part, nil
}

func (r *PartRepository) UpdateServiceByCatalogCodeForUser(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	catalogCode string,
	serviceMileageKM int,
	serviceDate time.Time,
) (domain.VehiclePart, error) {
	part, err := scanVehiclePart(r.db.QueryRowContext(ctx, `
		UPDATE parts p
		SET
			last_service_mileage_km = $4,
			last_service_date = $5,
			updated_at = NOW()
		FROM vehicles v
		WHERE
			p.vehicle_id = v.id
			AND v.user_id = $1
			AND p.vehicle_id = $2
			AND p.catalog_code = $3
		RETURNING
			p.id,
			p.vehicle_id,
			p.catalog_code,
			p.name,
			p.category,
			p.installed_at_mileage_km,
			p.last_service_mileage_km,
			p.last_service_date,
			p.created_at,
			p.updated_at
	`, userID, vehicleID, catalogCode, serviceMileageKM, serviceDate))
	if errors.Is(err, sql.ErrNoRows) {
		return domain.VehiclePart{}, ErrNotFound
	}
	if err != nil {
		return domain.VehiclePart{}, fmt.Errorf("update vehicle part service: %w", err)
	}

	return part, nil
}

func (r *PartRepository) DeleteForUser(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	partID int64,
) error {
	result, err := r.db.ExecContext(ctx, `
		DELETE FROM parts p
		USING vehicles v
		WHERE
			p.vehicle_id = v.id
			AND v.user_id = $1
			AND p.vehicle_id = $2
			AND p.id = $3
	`, userID, vehicleID, partID)
	if err != nil {
		return fmt.Errorf("delete vehicle part: %w", err)
	}

	count, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("get deleted parts count: %w", err)
	}
	if count == 0 {
		return ErrNotFound
	}

	return nil
}

func scanPartCatalogItem(scanner rowScanner) (domain.PartCatalogItem, error) {
	var item domain.PartCatalogItem

	err := scanner.Scan(
		&item.ID,
		&item.Code,
		&item.Name,
		&item.Category,
		&item.DefaultLifetimeKM,
		&item.DefaultLifetimeDays,
		&item.CreatedAt,
	)
	if err != nil {
		return domain.PartCatalogItem{}, err
	}

	return item, nil
}

func scanVehiclePart(scanner rowScanner) (domain.VehiclePart, error) {
	var part domain.VehiclePart
	var catalogCode sql.NullString
	var category sql.NullString
	var installedAtMileageKM sql.NullInt64
	var lastServiceMileageKM sql.NullInt64
	var lastServiceDate sql.NullTime

	err := scanner.Scan(
		&part.ID,
		&part.VehicleID,
		&catalogCode,
		&part.Name,
		&category,
		&installedAtMileageKM,
		&lastServiceMileageKM,
		&lastServiceDate,
		&part.CreatedAt,
		&part.UpdatedAt,
	)
	if err != nil {
		return domain.VehiclePart{}, err
	}

	if catalogCode.Valid {
		part.CatalogCode = &catalogCode.String
	}
	if category.Valid {
		part.Category = &category.String
	}
	if installedAtMileageKM.Valid {
		value := int(installedAtMileageKM.Int64)
		part.InstalledAtMileageKM = &value
	}
	if lastServiceMileageKM.Valid {
		value := int(lastServiceMileageKM.Int64)
		part.LastServiceMileageKM = &value
	}
	if lastServiceDate.Valid {
		part.LastServiceDate = &lastServiceDate.Time
	}

	return part, nil
}

func (r *PartRepository) vehicleBelongsToUser(
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
