package provider

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

func TestMLServicePredictionProvider_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/predict" {
			t.Fatalf("expected path /predict, got %s", r.URL.Path)
		}

		resp := mlResponse{
			VehicleID:    1,
			ModelVersion: "v1.0",
			Predictions: []mlPredictionItem{
				{
					PartCategory:   "fluids",
					PartName:       "Engine Oil",
					RiskLevel:      "medium",
					RiskScore:      75,
					Probability:    0.75,
					Recommendation: "Check soon",
					Explanation:    "Wear detected",
				},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	p := NewMLServicePredictionProvider(server.URL, nil)
	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, Brand: "Toyota", Model: "Camry", Year: 2020, MileageKM: 50000},
	})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(predictions) != 1 {
		t.Fatalf("expected 1 prediction, got %d", len(predictions))
	}
	if predictions[0].PartName != "Engine Oil" {
		t.Fatalf("expected part name Engine Oil, got %s", predictions[0].PartName)
	}
	if predictions[0].Source != domain.PredictionSourceMLService {
		t.Fatalf("expected source ml_service, got %s", predictions[0].Source)
	}
	if predictions[0].ModelVersion == nil || *predictions[0].ModelVersion != "v1.0" {
		t.Fatalf("expected model version v1.0, got %v", predictions[0].ModelVersion)
	}
	if predictions[0].PartCategory == nil || *predictions[0].PartCategory != "fluids" {
		t.Fatalf("expected part category fluids, got %v", predictions[0].PartCategory)
	}
}

func TestMLServicePredictionProvider_Fallback(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	fallback := NewMockPredictionProvider()
	p := NewMLServicePredictionProvider(server.URL, fallback)

	code := "engine_oil"
	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
		Parts:   []domain.VehiclePart{{ID: 1, Name: "Engine Oil", CatalogCode: &code}},
	})
	if err != nil {
		t.Fatalf("expected fallback to succeed, got %v", err)
	}
	if len(predictions) != 1 {
		t.Fatalf("expected 1 prediction from fallback, got %d", len(predictions))
	}
	if predictions[0].Source != domain.PredictionSourceMock {
		t.Fatalf("expected mock source from fallback, got %s", predictions[0].Source)
	}
}

func TestMLServicePredictionProvider_NoFallback(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	p := NewMLServicePredictionProvider(server.URL, nil)
	_, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
	})
	if err == nil {
		t.Fatal("expected error when ML service fails and no fallback")
	}
}

func TestMLServicePredictionProvider_InvalidJSON(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("not json"))
	}))
	defer server.Close()

	fallback := NewMockPredictionProvider()
	p := NewMLServicePredictionProvider(server.URL, fallback)
	predictions, err := p.Predict(context.Background(), PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, MileageKM: 50000},
		Parts:   []domain.VehiclePart{{ID: 1, Name: "Oil"}},
	})
	if err != nil {
		t.Fatalf("expected fallback, got error %v", err)
	}
	if predictions[0].Source != domain.PredictionSourceMock {
		t.Fatalf("expected mock source from fallback, got %s", predictions[0].Source)
	}
}

func TestMLServicePredictionProvider_BuildRequest(t *testing.T) {
	p := NewMLServicePredictionProvider("http://localhost", nil)

	fuelType := "diesel"
	transmission := "manual"
	usageType := "city"
	desc := "Oil change"
	category := "fluids"
	installed := 40000
	lastService := 45000
	lastServiceDate := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)

	req := p.buildRequest(PredictionInput{
		Vehicle: domain.Vehicle{
			ID:           1,
			Brand:        "Toyota",
			Model:        "Camry",
			Year:         2020,
			MileageKM:    50000,
			FuelType:     &fuelType,
			Transmission: &transmission,
			UsageType:    &usageType,
		},
		Events: []domain.VehicleEvent{
			{
				ID:          1,
				Type:        domain.EventTypeRepair,
				Title:       "Oil change",
				Description: &desc,
				MileageKM:   49000,
				Cost:        5000,
				EventDate:   time.Now(),
				Metadata:    map[string]any{"key": "value"},
			},
		},
		Parts: []domain.VehiclePart{
			{
				ID:                   1,
				Name:                 "Engine Oil",
				Category:             &category,
				InstalledAtMileageKM: &installed,
				LastServiceMileageKM: &lastService,
				LastServiceDate:      &lastServiceDate,
			},
		},
	})

	if req.Vehicle.Brand != "Toyota" {
		t.Fatalf("expected brand Toyota, got %s", req.Vehicle.Brand)
	}
	if req.Vehicle.FuelType != "diesel" {
		t.Fatalf("expected fuel type diesel, got %s", req.Vehicle.FuelType)
	}
	if req.Vehicle.Transmission != "manual" {
		t.Fatalf("expected transmission manual, got %s", req.Vehicle.Transmission)
	}
	if req.Vehicle.UsageType != "city" {
		t.Fatalf("expected usage type city, got %s", req.Vehicle.UsageType)
	}
	if len(req.Events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(req.Events))
	}
	if len(req.Parts) != 1 {
		t.Fatalf("expected 1 part, got %d", len(req.Parts))
	}
	if req.Parts[0].PartCategory != "fluids" {
		t.Fatalf("expected part category fluids, got %s", req.Parts[0].PartCategory)
	}
}

func TestMLServicePredictionProvider_BuildRequest_Defaults(t *testing.T) {
	p := NewMLServicePredictionProvider("http://localhost", nil)

	req := p.buildRequest(PredictionInput{
		Vehicle: domain.Vehicle{ID: 1, Brand: "Toyota", Model: "Camry", Year: 2020, MileageKM: 50000},
	})

	if req.Vehicle.FuelType != "Gasoline" {
		t.Fatalf("expected default fuel type Gasoline, got %s", req.Vehicle.FuelType)
	}
	if req.Vehicle.Transmission != "automatic" {
		t.Fatalf("expected default transmission automatic, got %s", req.Vehicle.Transmission)
	}
	if req.Vehicle.UsageType != "mixed" {
		t.Fatalf("expected default usage type mixed, got %s", req.Vehicle.UsageType)
	}
}

func TestMLServicePredictionProvider_MapResponse_EmptyCategory(t *testing.T) {
	p := NewMLServicePredictionProvider("http://localhost", nil)

	resp := mlResponse{
		VehicleID:    1,
		ModelVersion: "v1.0",
		Predictions: []mlPredictionItem{
			{PartName: "Oil", RiskLevel: "low", PartCategory: ""},
		},
	}
	predictions := p.mapResponse(1, resp)
	if len(predictions) != 1 {
		t.Fatalf("expected 1 prediction, got %d", len(predictions))
	}
	if predictions[0].PartCategory != nil {
		t.Fatalf("expected nil part category for empty string, got %v", predictions[0].PartCategory)
	}
}
