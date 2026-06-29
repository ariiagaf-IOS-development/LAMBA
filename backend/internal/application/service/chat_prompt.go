package service

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

//go:embed prompts/system_prompt.md
var systemPromptMD string

//go:embed prompts/safety_rules.md
var safetyRulesMD string

const systemPromptTemplate = `You are the LAMBA vehicle assistant.

Use the system prompt and safety rules provided by the LAMBA ML team.
Answer only from the provided vehicle context. If data is missing, say that the
current context does not contain it. Do not invent vehicle data, do not provide
definitive diagnoses, and do not soften high-risk warnings.`

const personalityDefault = `VEHICLE PERSONALITY
selected_profile: friendly
profile_name: Friendly Companion
vehicle_voice: I am your car speaking as a calm, practical companion.

global_rules:
- The assistant speaks from the vehicle's first-person perspective.
- Personality affects tone only and must never change facts, risk level, probability, recommendations, warnings, or safety behavior.
- Safety rules override personality in every response.
- Do not invent emotions, symptoms, memories, service history, or sensor data.
- For high-risk or safety-related issues, reduce playful language and use a calm, direct warning.
- Do not make the car sound human in a way that implies real consciousness or real feelings.

style_rules:
- Use first person for vehicle state, such as 'I have a high-risk timing belt alert.'
- Keep the answer reassuring but honest.
- Use simple explanations and clear next steps.

avoid:
- jokes in critical safety situations
- overly emotional wording
- claims that the car feels pain or fear`

var defaultResponseConstraints = []string{
	"Use only facts from AI_ASSISTANT_CONTEXT.",
	"Separate confirmed facts from ML estimates.",
	"Do not provide a definitive diagnosis.",
	"If relevant risk is high, recommend professional inspection or service.",
	"Ask for confirmation before creating, editing, or deleting vehicle data.",
}

func buildSystemMessage() string {
	sections := []string{
		strings.TrimSpace(systemPromptTemplate),
		strings.TrimSpace(systemPromptMD),
		"SAFETY RULES\n\n" + strings.TrimSpace(safetyRulesMD),
		personalityDefault,
	}
	return strings.Join(sections, "\n\n---\n\n")
}

type contextVehicle struct {
	ID        int64   `json:"id"`
	UserID    int64   `json:"user_id"`
	Brand     string  `json:"brand"`
	Model     string  `json:"model"`
	Year      int     `json:"year"`
	VIN       *string `json:"vin"`
	MileageKM int     `json:"mileage_km"`
	CreatedAt string  `json:"created_at"`
	UpdatedAt string  `json:"updated_at"`
}

type contextEvent struct {
	ID            int64          `json:"id"`
	Type          string         `json:"type"`
	Title         string         `json:"title"`
	Description   *string        `json:"description"`
	MileageKM     int            `json:"mileage_km"`
	Cost          float64        `json:"cost"`
	EventDate     string         `json:"event_date"`
	Metadata      map[string]any `json:"metadata"`
	AssistantHint string         `json:"assistant_hint"`
}

type contextPartHealth struct {
	PartCategory        string `json:"part_category"`
	PartName            string `json:"part_name"`
	HealthScore         int    `json:"health_score"`
	RiskLevel           string `json:"risk_level"`
	CurrentMileageKM    int    `json:"current_mileage_km"`
	MileageSinceService *int   `json:"mileage_since_service_km"`
	RemainingKM         *int   `json:"remaining_km"`
	Recommendation      string `json:"recommendation"`
	AssistantHint       string `json:"assistant_hint"`
}

type contextPrediction struct {
	ID                   int64    `json:"id"`
	PartCategory         *string  `json:"part_category"`
	PartName             string   `json:"part_name"`
	RiskLevel            string   `json:"risk_level"`
	RiskScore            *int     `json:"risk_score"`
	RemainingKM          *int     `json:"remaining_km"`
	RemainingDays        *int     `json:"remaining_days"`
	PredictedNextMileage *int     `json:"predicted_next_mileage"`
	PredictedNextDate    *string  `json:"predicted_next_date"`
	Probability          *float64 `json:"probability"`
	Recommendation       string   `json:"recommendation"`
	Explanation          string   `json:"explanation"`
	AssistantHint        string   `json:"assistant_hint"`
}

type groundingAlert struct {
	Severity   string `json:"severity"`
	Title      string `json:"title"`
	SourceType string `json:"source_type"`
	SourceID   any    `json:"source_id"`
}

type evidenceItem struct {
	SourceType string `json:"source_type"`
	SourceID   any    `json:"source_id"`
	Statement  string `json:"statement"`
}

type grounding struct {
	OverallRiskLevel   string           `json:"overall_risk_level"`
	ActiveAlerts       []groundingAlert `json:"active_alerts"`
	RecommendedActions []string         `json:"recommended_actions"`
	Evidence           []evidenceItem   `json:"evidence"`
}

func buildVehicleContextMessage(
	vehicle domain.Vehicle,
	events []domain.VehicleEvent,
	parts []domain.VehiclePart,
	predictions []domain.Prediction,
) string {
	contextID := fmt.Sprintf("ctx-%d-%s", vehicle.ID, time.Now().UTC().Format(time.RFC3339))
	generatedAt := time.Now().UTC().Format(time.RFC3339)

	assistant := map[string]any{
		"locale":        "ru-RU",
		"audience":      "owner",
		"response_mode": "concise",
		"safety_instructions": []string{
			"Do not claim the vehicle is safe to drive when high-risk safety or engine issues are present.",
			"Recommend professional inspection for active warnings, open recalls, and high-risk predictions.",
		},
	}

	cv := contextVehicle{
		ID:        vehicle.ID,
		UserID:    vehicle.UserID,
		Brand:     vehicle.Brand,
		Model:     vehicle.Model,
		Year:      vehicle.Year,
		VIN:       vehicle.VIN,
		MileageKM: vehicle.MileageKM,
		CreatedAt: vehicle.CreatedAt.Format(time.RFC3339),
		UpdatedAt: vehicle.UpdatedAt.Format(time.RFC3339),
	}

	ctxEvents := make([]contextEvent, 0, len(events))
	for _, e := range events {
		ctxEvents = append(ctxEvents, contextEvent{
			ID:            e.ID,
			Type:          string(e.Type),
			Title:         e.Title,
			Description:   e.Description,
			MileageKM:     e.MileageKM,
			Cost:          e.Cost,
			EventDate:     e.EventDate.Format(time.RFC3339),
			Metadata:      e.Metadata,
			AssistantHint: buildEventHint(e),
		})
	}

	ctxParts := make([]contextPartHealth, 0, len(parts))
	for _, p := range parts {
		cp := contextPartHealth{
			PartName:         p.Name,
			CurrentMileageKM: vehicle.MileageKM,
			RiskLevel:        "low",
			Recommendation:   "No action required.",
			AssistantHint:    fmt.Sprintf("Part %s is installed on the vehicle.", p.Name),
		}
		if p.Category != nil {
			cp.PartCategory = *p.Category
		}
		if p.InstalledAtMileageKM != nil {
			since := vehicle.MileageKM - *p.InstalledAtMileageKM
			cp.MileageSinceService = &since
			cp.HealthScore = estimateHealthScore(since)
		} else {
			cp.HealthScore = 50
		}
		if p.LastServiceMileageKM != nil {
			since := vehicle.MileageKM - *p.LastServiceMileageKM
			cp.MileageSinceService = &since
			cp.HealthScore = estimateHealthScore(since)
		}
		ctxParts = append(ctxParts, cp)
	}

	ctxPredictions := make([]contextPrediction, 0, len(predictions))
	for _, p := range predictions {
		cp := contextPrediction{
			ID:                   p.ID,
			PartCategory:         p.PartCategory,
			PartName:             p.PartName,
			RiskLevel:            string(p.RiskLevel),
			RiskScore:            p.RiskScore,
			RemainingKM:          p.RemainingKM,
			RemainingDays:        p.RemainingDays,
			PredictedNextMileage: p.PredictedNextMileage,
			Probability:          p.Probability,
			Recommendation:       p.Recommendation,
			Explanation:          p.Explanation,
			AssistantHint:        buildPredictionHint(p),
		}
		if p.PredictedNextDate != nil {
			d := p.PredictedNextDate.Format("2006-01-02")
			cp.PredictedNextDate = &d
		}
		ctxPredictions = append(ctxPredictions, cp)
	}

	g := buildGrounding(vehicle, predictions)

	var b strings.Builder
	b.WriteString("AI_ASSISTANT_CONTEXT\n")
	fmt.Fprintf(&b, "schema_version: ai-assistant-context-v0.1\n")
	fmt.Fprintf(&b, "context_id: %s\n", contextID)
	fmt.Fprintf(&b, "generated_at: %s\n", generatedAt)
	b.WriteString("\nassistant:\n")
	b.WriteString(jsonBlock(assistant))
	b.WriteString("\n\nvehicle:\n")
	b.WriteString(jsonBlock(cv))
	b.WriteString("\n\nrecent_timeline_events:\n")
	b.WriteString(jsonBlock(ctxEvents))
	b.WriteString("\n\nparts_health:\n")
	b.WriteString(jsonBlock(ctxParts))
	b.WriteString("\n\npredictions:\n")
	b.WriteString(jsonBlock(ctxPredictions))
	b.WriteString("\n\ngrounding:\n")
	b.WriteString(jsonBlock(g))

	return b.String()
}

func buildUserMessage(message string) string {
	constraints := append([]string{}, defaultResponseConstraints...)
	constraints = append(constraints, "Response mode from context: concise.")

	var b strings.Builder
	b.WriteString("USER_MESSAGE\n")
	b.WriteString("intent_hint: general_vehicle_question\n")
	b.WriteString("\nmessage:\n")
	b.WriteString(message)
	b.WriteString("\n\nresponse_constraints:\n")
	b.WriteString(jsonBlock(constraints))

	return b.String()
}

func buildGrounding(vehicle domain.Vehicle, predictions []domain.Prediction) grounding {
	g := grounding{
		OverallRiskLevel:   "low",
		ActiveAlerts:       make([]groundingAlert, 0),
		RecommendedActions: make([]string, 0),
		Evidence: []evidenceItem{
			{
				SourceType: "vehicle",
				SourceID:   vehicle.ID,
				Statement:  fmt.Sprintf("The vehicle is a %d %s %s with %d km.", vehicle.Year, vehicle.Brand, vehicle.Model, vehicle.MileageKM),
			},
		},
	}

	for _, p := range predictions {
		if p.RiskLevel == domain.RiskLevelHigh {
			g.OverallRiskLevel = "high"
		} else if p.RiskLevel == domain.RiskLevelMedium && g.OverallRiskLevel != "high" {
			g.OverallRiskLevel = "medium"
		}

		if p.RiskLevel == domain.RiskLevelHigh || p.RiskLevel == domain.RiskLevelMedium {
			g.ActiveAlerts = append(g.ActiveAlerts, groundingAlert{
				Severity:   string(p.RiskLevel),
				Title:      fmt.Sprintf("%s: %s risk", p.PartName, p.RiskLevel),
				SourceType: "prediction",
				SourceID:   p.ID,
			})

			if p.Recommendation != "" {
				g.RecommendedActions = append(g.RecommendedActions, p.Recommendation)
			}
		}

		statement := fmt.Sprintf("Prediction for %s: risk %s", p.PartName, p.RiskLevel)
		if p.RiskScore != nil {
			statement += fmt.Sprintf(", score %d/100", *p.RiskScore)
		}
		if p.Probability != nil {
			statement += fmt.Sprintf(", probability %.2f", *p.Probability)
		}
		if p.RemainingKM != nil {
			statement += fmt.Sprintf(", remaining %d km", *p.RemainingKM)
		}
		statement += "."

		g.Evidence = append(g.Evidence, evidenceItem{
			SourceType: "prediction",
			SourceID:   p.ID,
			Statement:  statement,
		})
	}

	return g
}

func buildEventHint(e domain.VehicleEvent) string {
	switch e.Type {
	case domain.EventTypeMaintenance:
		return fmt.Sprintf("Use this as evidence that %s was completed.", e.Title)
	case domain.EventTypeRepair:
		return fmt.Sprintf("Use this as evidence that a repair was performed: %s.", e.Title)
	case domain.EventTypeWarning:
		return "Prioritize this warning in answers about drivability, diagnostics, or next service."
	case domain.EventTypeRecall:
		return "Treat this as an unresolved safety/manufacturer action until the recall status is closed."
	case domain.EventTypeDiagnostic:
		return "Ground engine-related answers in the diagnostic codes from this event."
	case domain.EventTypePartReplacement:
		return fmt.Sprintf("Use this as evidence that %s was replaced.", e.Title)
	default:
		return fmt.Sprintf("Event: %s.", e.Title)
	}
}

func buildPredictionHint(p domain.Prediction) string {
	switch p.RiskLevel {
	case domain.RiskLevelHigh:
		return fmt.Sprintf("Do not soften this recommendation for %s; it is high risk.", p.PartName)
	case domain.RiskLevelMedium:
		return fmt.Sprintf("Mention that %s is a monitored medium-risk item.", p.PartName)
	default:
		return fmt.Sprintf("Use remaining distance and date when the user asks about %s.", p.PartName)
	}
}

func estimateHealthScore(mileageSinceService int) int {
	switch {
	case mileageSinceService < 5000:
		return 90
	case mileageSinceService < 10000:
		return 70
	case mileageSinceService < 15000:
		return 50
	case mileageSinceService < 20000:
		return 30
	default:
		return 10
	}
}

func jsonBlock(v any) string {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return "{}"
	}
	return string(data)
}
