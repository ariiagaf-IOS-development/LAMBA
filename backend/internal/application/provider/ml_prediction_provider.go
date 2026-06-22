package provider

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

const mlRequestTimeout = 30 * time.Second

type MLServicePredictionProvider struct {
	baseURL  string
	client   *http.Client
	fallback PredictionProvider
}

func NewMLServicePredictionProvider(baseURL string, fallback PredictionProvider) *MLServicePredictionProvider {
	return &MLServicePredictionProvider{
		baseURL: baseURL,
		client: &http.Client{
			Timeout: mlRequestTimeout,
		},
		fallback: fallback,
	}
}

type mlVehicle struct {
	ID           int64   `json:"id"`
	Brand        string  `json:"brand"`
	Model        string  `json:"model"`
	Year         int     `json:"year"`
	VIN          *string `json:"vin"`
	MileageKM    int     `json:"mileage_km"`
	FuelType     string  `json:"fuel_type"`
	Transmission string  `json:"transmission"`
	UsageType    string  `json:"usage_type"`
}

type mlEvent struct {
	ID          int64          `json:"id"`
	Type        string         `json:"type"`
	Title       string         `json:"title"`
	Description *string        `json:"description"`
	MileageKM   int            `json:"mileage_km"`
	Cost        float64        `json:"cost"`
	EventDate   string         `json:"event_date"`
	Metadata    map[string]any `json:"metadata"`
}

type mlPart struct {
	PartCategory         string  `json:"part_category"`
	PartName             string  `json:"part_name"`
	InstalledAtMileageKM *int    `json:"installed_at_mileage_km"`
	LastServiceMileageKM *int    `json:"last_service_mileage_km"`
	LastServiceDate      *string `json:"last_service_date"`
}

type mlRequest struct {
	RequestID string    `json:"request_id"`
	Vehicle   mlVehicle `json:"vehicle"`
	Events    []mlEvent `json:"events"`
	Parts     []mlPart  `json:"parts"`
}

type mlPredictionItem struct {
	PartCategory         string  `json:"part_category"`
	PartName             string  `json:"part_name"`
	RiskLevel            string  `json:"risk_level"`
	RiskScore            int     `json:"risk_score"`
	RemainingKM          *int    `json:"remaining_km"`
	RemainingDays        *int    `json:"remaining_days"`
	PredictedNextMileage *int    `json:"predicted_next_mileage"`
	PredictedNextDate    *string `json:"predicted_next_date"`
	Probability          float64 `json:"probability"`
	Recommendation       string  `json:"recommendation"`
	Explanation          string  `json:"explanation"`
}

type mlResponse struct {
	VehicleID    int64              `json:"vehicle_id"`
	ModelVersion string             `json:"model_version"`
	Predictions  []mlPredictionItem `json:"predictions"`
}

func (p *MLServicePredictionProvider) Predict(
	ctx context.Context,
	input PredictionInput,
) ([]domain.Prediction, error) {
	predictions, err := p.callMLService(ctx, input)
	if err != nil && p.fallback != nil {
		return p.fallback.Predict(ctx, input)
	}

	return predictions, err
}

func (p *MLServicePredictionProvider) callMLService(
	ctx context.Context,
	input PredictionInput,
) ([]domain.Prediction, error) {
	reqBody := p.buildRequest(input)

	jsonBody, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("marshal ml request: %w", err)
	}

	url := p.baseURL + "/predict"

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(jsonBody))
	if err != nil {
		return nil, fmt.Errorf("create ml request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := p.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("call ml service: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read ml response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("ml service returned status %d: %s", resp.StatusCode, string(body))
	}

	var mlResp mlResponse
	if err := json.Unmarshal(body, &mlResp); err != nil {
		return nil, fmt.Errorf("unmarshal ml response: %w", err)
	}

	return p.mapResponse(input.Vehicle.ID, mlResp), nil
}

func (p *MLServicePredictionProvider) buildRequest(input PredictionInput) mlRequest {
	fuelType := "Gasoline"
	if input.Vehicle.FuelType != nil {
		fuelType = *input.Vehicle.FuelType
	}

	transmission := "automatic"
	if input.Vehicle.Transmission != nil {
		transmission = *input.Vehicle.Transmission
	}

	usageType := "mixed"
	if input.Vehicle.UsageType != nil {
		usageType = *input.Vehicle.UsageType
	}

	reqID := fmt.Sprintf("pred-%d-%d", input.Vehicle.ID, time.Now().Unix())

	events := make([]mlEvent, 0, len(input.Events))
	for _, e := range input.Events {
		events = append(events, mlEvent{
			ID:          e.ID,
			Type:        string(e.Type),
			Title:       e.Title,
			Description: e.Description,
			MileageKM:   e.MileageKM,
			Cost:        e.Cost,
			EventDate:   e.EventDate.Format(time.RFC3339),
			Metadata:    e.Metadata,
		})
	}

	parts := make([]mlPart, 0, len(input.Parts))
	for _, pt := range input.Parts {
		mp := mlPart{
			PartName:             pt.Name,
			InstalledAtMileageKM: pt.InstalledAtMileageKM,
			LastServiceMileageKM: pt.LastServiceMileageKM,
		}

		if pt.Category != nil {
			mp.PartCategory = *pt.Category
		}

		if pt.LastServiceDate != nil {
			formatted := pt.LastServiceDate.Format(time.RFC3339)
			mp.LastServiceDate = &formatted
		}

		parts = append(parts, mp)
	}

	return mlRequest{
		RequestID: reqID,
		Vehicle: mlVehicle{
			ID:           input.Vehicle.ID,
			Brand:        input.Vehicle.Brand,
			Model:        input.Vehicle.Model,
			Year:         input.Vehicle.Year,
			VIN:          input.Vehicle.VIN,
			MileageKM:    input.Vehicle.MileageKM,
			FuelType:     fuelType,
			Transmission: transmission,
			UsageType:    usageType,
		},
		Events: events,
		Parts:  parts,
	}
}

func (p *MLServicePredictionProvider) mapResponse(
	vehicleID int64,
	resp mlResponse,
) []domain.Prediction {
	predictions := make([]domain.Prediction, 0, len(resp.Predictions))

	for _, item := range resp.Predictions {
		pred := domain.Prediction{
			VehicleID:            vehicleID,
			PartName:             item.PartName,
			RiskLevel:            domain.RiskLevel(item.RiskLevel),
			RiskScore:            &item.RiskScore,
			RemainingKM:          item.RemainingKM,
			RemainingDays:        item.RemainingDays,
			PredictedNextMileage: item.PredictedNextMileage,
			Probability:          &item.Probability,
			Recommendation:       item.Recommendation,
			Explanation:          item.Explanation,
			Source:               domain.PredictionSourceMLService,
			ModelVersion:         &resp.ModelVersion,
		}

		if item.PartCategory != "" {
			cat := item.PartCategory
			pred.PartCategory = &cat
		}

		predictions = append(predictions, pred)
	}

	return predictions
}
