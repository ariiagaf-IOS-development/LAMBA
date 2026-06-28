package repository

import (
	"context"
	"database/sql"
	"fmt"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

type PredictionRepository struct {
	db *sql.DB
}

func NewPredictionRepository(db *sql.DB) *PredictionRepository {
	return &PredictionRepository{db: db}
}

func (r *PredictionRepository) ListLatestByVehicleForUser(
	ctx context.Context,
	userID int64,
	vehicleID int64,
) ([]domain.Prediction, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT DISTINCT ON (p.part_name)
			p.id,
			p.vehicle_id,
			p.part_code,
			p.part_name,
			p.part_category,
			p.risk_level,
			p.risk_score,
			p.remaining_km,
			p.remaining_days,
			p.predicted_next_mileage,
			p.predicted_next_date,
			p.probability,
			p.recommendation,
			p.explanation,
			p.source,
			p.model_version,
			p.created_at
		FROM predictions p
		JOIN vehicles v ON v.id = p.vehicle_id
		WHERE p.vehicle_id = $1 AND v.user_id = $2
		ORDER BY p.part_name, p.created_at DESC, p.id DESC
	`, vehicleID, userID)
	if err != nil {
		return nil, fmt.Errorf("list latest predictions: %w", err)
	}
	defer rows.Close()

	predictions := make([]domain.Prediction, 0)
	for rows.Next() {
		prediction, err := scanPrediction(rows)
		if err != nil {
			return nil, fmt.Errorf("scan prediction: %w", err)
		}
		predictions = append(predictions, prediction)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate predictions: %w", err)
	}

	if len(predictions) == 0 {
		exists, err := r.vehicleBelongsToUser(ctx, userID, vehicleID)
		if err != nil {
			return nil, err
		}
		if !exists {
			return nil, ErrNotFound
		}
	}

	return predictions, nil
}

func (r *PredictionRepository) ReplaceForVehicleForUser(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	predictions []domain.Prediction,
) ([]domain.Prediction, error) {
	exists, err := r.vehicleBelongsToUser(ctx, userID, vehicleID)
	if err != nil {
		return nil, err
	}
	if !exists {
		return nil, ErrNotFound
	}

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin replace predictions tx: %w", err)
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx, `
		DELETE FROM predictions
		WHERE vehicle_id = $1
	`, vehicleID); err != nil {
		return nil, fmt.Errorf("delete old predictions: %w", err)
	}

	saved := make([]domain.Prediction, 0, len(predictions))
	for _, prediction := range predictions {
		prediction.VehicleID = vehicleID

		created, err := scanPrediction(tx.QueryRowContext(ctx, `
			INSERT INTO predictions (
				vehicle_id,
				part_code,
				part_name,
				part_category,
				risk_level,
				risk_score,
				remaining_km,
				remaining_days,
				predicted_next_mileage,
				predicted_next_date,
				probability,
				recommendation,
				explanation,
				source,
				model_version
			)
			VALUES (
				$1, $2, $3, $4, $5,
				$6, $7, $8, $9, $10,
				$11, $12, $13, $14, $15
			)
			RETURNING
				id,
				vehicle_id,
				part_code,
				part_name,
				part_category,
				risk_level,
				risk_score,
				remaining_km,
				remaining_days,
				predicted_next_mileage,
				predicted_next_date,
				probability,
				recommendation,
				explanation,
				source,
				model_version,
				created_at
		`,
			prediction.VehicleID,
			prediction.PartCode,
			prediction.PartName,
			prediction.PartCategory,
			prediction.RiskLevel,
			prediction.RiskScore,
			prediction.RemainingKM,
			prediction.RemainingDays,
			prediction.PredictedNextMileage,
			prediction.PredictedNextDate,
			prediction.Probability,
			prediction.Recommendation,
			prediction.Explanation,
			prediction.Source,
			prediction.ModelVersion,
		))
		if err != nil {
			return nil, fmt.Errorf("insert prediction: %w", err)
		}

		saved = append(saved, created)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit replace predictions tx: %w", err)
	}

	return saved, nil
}

func scanPrediction(scanner rowScanner) (domain.Prediction, error) {
	var prediction domain.Prediction
	var partCode sql.NullString
	var partCategory sql.NullString
	var riskScore sql.NullInt64
	var remainingKM sql.NullInt64
	var remainingDays sql.NullInt64
	var predictedNextMileage sql.NullInt64
	var predictedNextDate sql.NullTime
	var probability sql.NullFloat64
	var modelVersion sql.NullString
	var explanation sql.NullString

	err := scanner.Scan(
		&prediction.ID,
		&prediction.VehicleID,
		&partCode,
		&prediction.PartName,
		&partCategory,
		&prediction.RiskLevel,
		&riskScore,
		&remainingKM,
		&remainingDays,
		&predictedNextMileage,
		&predictedNextDate,
		&probability,
		&prediction.Recommendation,
		&explanation,
		&prediction.Source,
		&modelVersion,
		&prediction.CreatedAt,
	)
	if err != nil {
		return domain.Prediction{}, err
	}

	if partCode.Valid {
		prediction.PartCode = &partCode.String
	}
	if partCategory.Valid {
		prediction.PartCategory = &partCategory.String
	}
	if riskScore.Valid {
		value := int(riskScore.Int64)
		prediction.RiskScore = &value
	}
	if remainingKM.Valid {
		value := int(remainingKM.Int64)
		prediction.RemainingKM = &value
	}
	if remainingDays.Valid {
		value := int(remainingDays.Int64)
		prediction.RemainingDays = &value
	}
	if predictedNextMileage.Valid {
		value := int(predictedNextMileage.Int64)
		prediction.PredictedNextMileage = &value
	}
	if predictedNextDate.Valid {
		prediction.PredictedNextDate = &predictedNextDate.Time
	}
	if probability.Valid {
		prediction.Probability = &probability.Float64
	}
	if explanation.Valid {
		prediction.Explanation = explanation.String
	}
	if modelVersion.Valid {
		prediction.ModelVersion = &modelVersion.String
	}

	return prediction, nil
}

func (r *PredictionRepository) ListLatestByVehicle(
	ctx context.Context,
	vehicleID int64,
) ([]domain.Prediction, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT DISTINCT ON (p.part_name)
			p.id,
			p.vehicle_id,
			p.part_code,
			p.part_name,
			p.part_category,
			p.risk_level,
			p.risk_score,
			p.remaining_km,
			p.remaining_days,
			p.predicted_next_mileage,
			p.predicted_next_date,
			p.probability,
			p.recommendation,
			p.explanation,
			p.source,
			p.model_version,
			p.created_at
		FROM predictions p
		WHERE p.vehicle_id = $1
		ORDER BY p.part_name, p.created_at DESC, p.id DESC
	`, vehicleID)
	if err != nil {
		return nil, fmt.Errorf("list latest predictions by vehicle: %w", err)
	}
	defer rows.Close()

	predictions := make([]domain.Prediction, 0)
	for rows.Next() {
		prediction, err := scanPrediction(rows)
		if err != nil {
			return nil, fmt.Errorf("scan prediction: %w", err)
		}
		predictions = append(predictions, prediction)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate predictions: %w", err)
	}

	if len(predictions) == 0 {
		exists, err := r.vehicleExists(ctx, vehicleID)
		if err != nil {
			return nil, err
		}
		if !exists {
			return nil, ErrNotFound
		}
	}

	return predictions, nil
}

func (r *PredictionRepository) ReplaceForVehicle(
	ctx context.Context,
	vehicleID int64,
	predictions []domain.Prediction,
) ([]domain.Prediction, error) {
	exists, err := r.vehicleExists(ctx, vehicleID)
	if err != nil {
		return nil, err
	}
	if !exists {
		return nil, ErrNotFound
	}

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("begin replace predictions tx: %w", err)
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx, `
		DELETE FROM predictions
		WHERE vehicle_id = $1
	`, vehicleID); err != nil {
		return nil, fmt.Errorf("delete old predictions: %w", err)
	}

	saved := make([]domain.Prediction, 0, len(predictions))
	for _, prediction := range predictions {
		prediction.VehicleID = vehicleID

		created, err := scanPrediction(tx.QueryRowContext(ctx, `
			INSERT INTO predictions (
				vehicle_id,
				part_code,
				part_name,
				part_category,
				risk_level,
				risk_score,
				remaining_km,
				remaining_days,
				predicted_next_mileage,
				predicted_next_date,
				probability,
				recommendation,
				explanation,
				source,
				model_version
			)
			VALUES (
				$1, $2, $3, $4, $5,
				$6, $7, $8, $9, $10,
				$11, $12, $13, $14, $15
			)
			RETURNING
				id,
				vehicle_id,
				part_code,
				part_name,
				part_category,
				risk_level,
				risk_score,
				remaining_km,
				remaining_days,
				predicted_next_mileage,
				predicted_next_date,
				probability,
				recommendation,
				explanation,
				source,
				model_version,
				created_at
		`,
			prediction.VehicleID,
			prediction.PartCode,
			prediction.PartName,
			prediction.PartCategory,
			prediction.RiskLevel,
			prediction.RiskScore,
			prediction.RemainingKM,
			prediction.RemainingDays,
			prediction.PredictedNextMileage,
			prediction.PredictedNextDate,
			prediction.Probability,
			prediction.Recommendation,
			prediction.Explanation,
			prediction.Source,
			prediction.ModelVersion,
		))
		if err != nil {
			return nil, fmt.Errorf("insert prediction: %w", err)
		}

		saved = append(saved, created)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("commit replace predictions tx: %w", err)
	}

	return saved, nil
}

func (r *PredictionRepository) vehicleExists(
	ctx context.Context,
	vehicleID int64,
) (bool, error) {
	var exists bool

	err := r.db.QueryRowContext(ctx, `
		SELECT EXISTS (
			SELECT 1
			FROM vehicles
			WHERE id = $1
		)
	`, vehicleID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check vehicle exists: %w", err)
	}

	return exists, nil
}

func (r *PredictionRepository) vehicleBelongsToUser(
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
