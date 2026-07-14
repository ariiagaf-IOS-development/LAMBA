package service

import (
	"context"
	"errors"
	"strings"
	"time"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/infrastructure/repository"
)

var (
	ErrVehicleBrandRequired  = errors.New("brand is required")
	ErrVehicleModelRequired  = errors.New("model is required")
	ErrVehicleInvalidMileage = errors.New("mileage_km must be greater than or equal to 0")
	ErrVehicleInvalidYear    = errors.New("year must be between 1886 and next calendar year")
	ErrVehicleInvalidVIN     = errors.New("vin must be 17 characters")
)

type VehicleService struct {
	vehicles *repository.VehicleRepository
}

type CreateVehicleInput struct {
	Brand        string
	Model        string
	Year         int
	VIN          *string
	MileageKM    int
	FuelType     *string
	Transmission *string
	UsageType    *string
}

type UpdateVehicleInput struct {
	Brand        *string
	Model        *string
	Year         *int
	VIN          *string
	MileageKM    *int
	FuelType     *string
	Transmission *string
	UsageType    *string
}

func NewVehicleService(vehicles *repository.VehicleRepository) *VehicleService {
	return &VehicleService{vehicles: vehicles}
}

func (s *VehicleService) Create(
	ctx context.Context,
	userID int64,
	input CreateVehicleInput,
) (domain.Vehicle, error) {
	vehicle, err := newVehicleFromInput(input)
	if err != nil {
		return domain.Vehicle{}, err
	}

	vehicle.UserID = userID

	return s.vehicles.Create(ctx, vehicle)
}

func (s *VehicleService) List(
	ctx context.Context,
	userID int64,
) ([]domain.Vehicle, error) {
	return s.vehicles.ListByUser(ctx, userID)
}

func (s *VehicleService) Get(
	ctx context.Context,
	userID int64,
	vehicleID int64,
) (domain.Vehicle, error) {
	return s.vehicles.GetByIDForUser(ctx, userID, vehicleID)
}

func (s *VehicleService) Update(
	ctx context.Context,
	userID int64,
	vehicleID int64,
	input UpdateVehicleInput,
) (domain.Vehicle, error) {
	update, err := newVehicleUpdateFromInput(input)
	if err != nil {
		return domain.Vehicle{}, err
	}

	return s.vehicles.Update(ctx, userID, vehicleID, update)
}

func (s *VehicleService) Delete(
	ctx context.Context,
	userID int64,
	vehicleID int64,
) error {
	return s.vehicles.Delete(ctx, userID, vehicleID)
}

func newVehicleFromInput(input CreateVehicleInput) (domain.Vehicle, error) {
	brand := strings.TrimSpace(input.Brand)
	if brand == "" {
		return domain.Vehicle{}, ErrVehicleBrandRequired
	}

	model := strings.TrimSpace(input.Model)
	if model == "" {
		return domain.Vehicle{}, ErrVehicleModelRequired
	}

	if err := validateVehicleYear(input.Year); err != nil {
		return domain.Vehicle{}, err
	}

	if input.MileageKM < 0 {
		return domain.Vehicle{}, ErrVehicleInvalidMileage
	}

	normalizedVIN, err := normalizeVIN(input.VIN)
	if err != nil {
		return domain.Vehicle{}, err
	}

	return domain.Vehicle{
		Brand:        brand,
		Model:        model,
		Year:         input.Year,
		VIN:          normalizedVIN,
		MileageKM:    input.MileageKM,
		FuelType:     input.FuelType,
		Transmission: input.Transmission,
		UsageType:    input.UsageType,
	}, nil
}

func newVehicleUpdateFromInput(input UpdateVehicleInput) (repository.VehicleUpdate, error) {
	var update repository.VehicleUpdate

	if input.Brand != nil {
		brand := strings.TrimSpace(*input.Brand)
		if brand == "" {
			return update, ErrVehicleBrandRequired
		}

		update.Brand = &brand
	}

	if input.Model != nil {
		model := strings.TrimSpace(*input.Model)
		if model == "" {
			return update, ErrVehicleModelRequired
		}

		update.Model = &model
	}

	if input.Year != nil {
		if err := validateVehicleYear(*input.Year); err != nil {
			return update, err
		}

		update.Year = input.Year
	}

	if input.VIN != nil {
		vin, err := normalizeVIN(input.VIN)
		if err != nil {
			return update, err
		}

		update.VIN.Set = true
		update.VIN.Value = vin
	}

	if input.MileageKM != nil {
		if *input.MileageKM < 0 {
			return update, ErrVehicleInvalidMileage
		}

		update.MileageKM = input.MileageKM
	}

	if input.FuelType != nil {
		update.FuelType.Set = true
		update.FuelType.Value = input.FuelType
	}

	if input.Transmission != nil {
		update.Transmission.Set = true
		update.Transmission.Value = input.Transmission
	}

	if input.UsageType != nil {
		update.UsageType.Set = true
		update.UsageType.Value = input.UsageType
	}

	return update, nil
}

func validateVehicleYear(year int) error {
	currentMax := time.Now().Year() + 1
	if year < 1886 || year > currentMax {
		return ErrVehicleInvalidYear
	}

	return nil
}

func normalizeVIN(vin *string) (*string, error) {
	if vin == nil {
		return nil, nil
	}

	trimmed := strings.ToUpper(strings.TrimSpace(*vin))
	if trimmed == "" {
		return nil, nil
	}

	if len(trimmed) != 17 {
		return nil, ErrVehicleInvalidVIN
	}

	return &trimmed, nil
}
