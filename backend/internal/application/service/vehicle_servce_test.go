package service

import (
	"testing"
	"time"
)

func TestNewVehicleFromInput_EmptyBrand(t *testing.T) {
	_, err := newVehicleFromInput(CreateVehicleInput{
		Brand: "  ",
		Model: "Camry",
		Year:  2020,
	})
	if err != ErrVehicleBrandRequired {
		t.Fatalf("expected ErrVehicleBrandRequired, got %v", err)
	}
}

func TestNewVehicleFromInput_EmptyModel(t *testing.T) {
	_, err := newVehicleFromInput(CreateVehicleInput{
		Brand: "Toyota",
		Model: "  ",
		Year:  2020,
	})
	if err != ErrVehicleModelRequired {
		t.Fatalf("expected ErrVehicleModelRequired, got %v", err)
	}
}

func TestNewVehicleFromInput_InvalidYear_TooOld(t *testing.T) {
	_, err := newVehicleFromInput(CreateVehicleInput{
		Brand: "Toyota",
		Model: "Camry",
		Year:  1885,
	})
	if err != ErrVehicleInvalidYear {
		t.Fatalf("expected ErrVehicleInvalidYear, got %v", err)
	}
}

func TestNewVehicleFromInput_InvalidYear_TooNew(t *testing.T) {
	futureYear := time.Now().Year() + 2
	_, err := newVehicleFromInput(CreateVehicleInput{
		Brand: "Toyota",
		Model: "Camry",
		Year:  futureYear,
	})
	if err != ErrVehicleInvalidYear {
		t.Fatalf("expected ErrVehicleInvalidYear, got %v", err)
	}
}

func TestNewVehicleFromInput_NegativeMileage(t *testing.T) {
	_, err := newVehicleFromInput(CreateVehicleInput{
		Brand:     "Toyota",
		Model:     "Camry",
		Year:      2020,
		MileageKM: -100,
	})
	if err != ErrVehicleInvalidMileage {
		t.Fatalf("expected ErrVehicleInvalidMileage, got %v", err)
	}
}

func TestNewVehicleFromInput_InvalidVIN(t *testing.T) {
	shortVIN := strPtr("ABC")
	_, err := newVehicleFromInput(CreateVehicleInput{
		Brand: "Toyota",
		Model: "Camry",
		Year:  2020,
		VIN:   shortVIN,
	})
	if err != ErrVehicleInvalidVIN {
		t.Fatalf("expected ErrVehicleInvalidVIN, got %v", err)
	}
}

func TestNewVehicleFromInput_ValidInput(t *testing.T) {
	vin := strPtr("JTDBE32K620123456")
	vehicle, err := newVehicleFromInput(CreateVehicleInput{
		Brand:     "Toyota",
		Model:     "Camry",
		Year:      2020,
		VIN:       vin,
		MileageKM: 42000,
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if vehicle.Brand != "Toyota" {
		t.Fatalf("expected brand Toyota, got %s", vehicle.Brand)
	}
	if vehicle.Model != "Camry" {
		t.Fatalf("expected model Camry, got %s", vehicle.Model)
	}
	if vehicle.VIN == nil || *vehicle.VIN != "JTDBE32K620123456" {
		t.Fatalf("expected VIN JTDBE32K620123456, got %v", vehicle.VIN)
	}
}

func TestNewVehicleFromInput_NilVIN(t *testing.T) {
	vehicle, err := newVehicleFromInput(CreateVehicleInput{
		Brand: "Toyota",
		Model: "Camry",
		Year:  2020,
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if vehicle.VIN != nil {
		t.Fatalf("expected nil VIN, got %v", vehicle.VIN)
	}
}

func TestNewVehicleFromInput_EmptyVIN(t *testing.T) {
	emptyVIN := strPtr("  ")
	vehicle, err := newVehicleFromInput(CreateVehicleInput{
		Brand: "Toyota",
		Model: "Camry",
		Year:  2020,
		VIN:   emptyVIN,
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if vehicle.VIN != nil {
		t.Fatalf("expected nil VIN for empty string, got %v", vehicle.VIN)
	}
}

func TestNewVehicleFromInput_VINUppercase(t *testing.T) {
	vin := strPtr("jtdbe32k620123456")
	vehicle, err := newVehicleFromInput(CreateVehicleInput{
		Brand: "Toyota",
		Model: "Camry",
		Year:  2020,
		VIN:   vin,
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if vehicle.VIN == nil || *vehicle.VIN != "JTDBE32K620123456" {
		t.Fatalf("expected uppercase VIN, got %v", vehicle.VIN)
	}
}

func TestNewVehicleUpdateFromInput_EmptyBrand(t *testing.T) {
	brand := "  "
	_, err := newVehicleUpdateFromInput(UpdateVehicleInput{Brand: &brand})
	if err != ErrVehicleBrandRequired {
		t.Fatalf("expected ErrVehicleBrandRequired, got %v", err)
	}
}

func TestNewVehicleUpdateFromInput_EmptyModel(t *testing.T) {
	model := "  "
	_, err := newVehicleUpdateFromInput(UpdateVehicleInput{Model: &model})
	if err != ErrVehicleModelRequired {
		t.Fatalf("expected ErrVehicleModelRequired, got %v", err)
	}
}

func TestNewVehicleUpdateFromInput_InvalidYear(t *testing.T) {
	year := 1800
	_, err := newVehicleUpdateFromInput(UpdateVehicleInput{Year: &year})
	if err != ErrVehicleInvalidYear {
		t.Fatalf("expected ErrVehicleInvalidYear, got %v", err)
	}
}

func TestNewVehicleUpdateFromInput_InvalidVIN(t *testing.T) {
	vin := "SHORT"
	_, err := newVehicleUpdateFromInput(UpdateVehicleInput{VIN: &vin})
	if err != ErrVehicleInvalidVIN {
		t.Fatalf("expected ErrVehicleInvalidVIN, got %v", err)
	}
}

func TestNewVehicleUpdateFromInput_NegativeMileage(t *testing.T) {
	mileage := -1
	_, err := newVehicleUpdateFromInput(UpdateVehicleInput{MileageKM: &mileage})
	if err != ErrVehicleInvalidMileage {
		t.Fatalf("expected ErrVehicleInvalidMileage, got %v", err)
	}
}

func TestNewVehicleUpdateFromInput_ValidPartialUpdate(t *testing.T) {
	brand := "Honda"
	mileage := 50000
	fuelType := "diesel"
	transmission := "manual"
	usageType := "city"

	update, err := newVehicleUpdateFromInput(UpdateVehicleInput{
		Brand:        &brand,
		MileageKM:    &mileage,
		FuelType:     &fuelType,
		Transmission: &transmission,
		UsageType:    &usageType,
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if update.Brand == nil || *update.Brand != "Honda" {
		t.Fatalf("expected brand Honda, got %v", update.Brand)
	}
	if update.MileageKM == nil || *update.MileageKM != 50000 {
		t.Fatalf("expected mileage 50000, got %v", update.MileageKM)
	}
	if !update.FuelType.Set || update.FuelType.Value == nil || *update.FuelType.Value != "diesel" {
		t.Fatalf("expected fuel type diesel")
	}
	if !update.Transmission.Set || update.Transmission.Value == nil || *update.Transmission.Value != "manual" {
		t.Fatalf("expected transmission manual")
	}
	if !update.UsageType.Set || update.UsageType.Value == nil || *update.UsageType.Value != "city" {
		t.Fatalf("expected usage type city")
	}
}

func TestNewVehicleUpdateFromInput_EmptyUpdate(t *testing.T) {
	update, err := newVehicleUpdateFromInput(UpdateVehicleInput{})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if update.Brand != nil || update.Model != nil || update.Year != nil || update.MileageKM != nil {
		t.Fatal("expected empty update")
	}
}

func TestValidateVehicleYear_Boundaries(t *testing.T) {
	if err := validateVehicleYear(1886); err != nil {
		t.Fatalf("expected year 1886 to be valid, got %v", err)
	}

	currentMax := time.Now().Year() + 1
	if err := validateVehicleYear(currentMax); err != nil {
		t.Fatalf("expected year %d to be valid, got %v", currentMax, err)
	}

	if err := validateVehicleYear(1885); err != ErrVehicleInvalidYear {
		t.Fatalf("expected ErrVehicleInvalidYear for 1885, got %v", err)
	}

	if err := validateVehicleYear(currentMax + 1); err != ErrVehicleInvalidYear {
		t.Fatalf("expected ErrVehicleInvalidYear for %d, got %v", currentMax+1, err)
	}
}

func TestNormalizeVIN(t *testing.T) {
	tests := []struct {
		name    string
		input   *string
		wantNil bool
		want    string
		wantErr error
	}{
		{"nil vin", nil, true, "", nil},
		{"empty vin", strPtr(""), true, "", nil},
		{"whitespace vin", strPtr("   "), true, "", nil},
		{"valid vin", strPtr("JTDBE32K620123456"), false, "JTDBE32K620123456", nil},
		{"lowercase vin", strPtr("jtdbe32k620123456"), false, "JTDBE32K620123456", nil},
		{"short vin", strPtr("ABC"), false, "", ErrVehicleInvalidVIN},
		{"long vin", strPtr("JTDBE32K620123456X"), false, "", ErrVehicleInvalidVIN},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := normalizeVIN(tt.input)
			if err != tt.wantErr {
				t.Fatalf("expected error %v, got %v", tt.wantErr, err)
			}
			if tt.wantErr != nil {
				return
			}
			if tt.wantNil && got != nil {
				t.Fatalf("expected nil, got %v", *got)
			}
			if !tt.wantNil && (got == nil || *got != tt.want) {
				t.Fatalf("expected %s, got %v", tt.want, got)
			}
		})
	}
}

func strPtr(s string) *string {
	return &s
}
