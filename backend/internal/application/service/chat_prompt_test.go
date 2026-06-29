package service

import (
	"strings"
	"testing"
	"time"

	"gitlab.pg.innopolis.university/lamba/LAMBA/backend/internal/domain"
)

func TestBuildSystemMessage(t *testing.T) {
	vehicle := domain.Vehicle{Brand: "Toyota", Model: "Camry", Year: 2020, MileageKM: 50000}
	msg := buildSystemMessage(vehicle, 10000)
	if msg == "" {
		t.Fatal("expected non-empty system message")
	}
	if !strings.Contains(msg, "LAMBA") {
		t.Fatal("expected system message to mention LAMBA")
	}
	if !strings.Contains(msg, "VEHICLE PERSONALITY") {
		t.Fatal("expected system message to contain VEHICLE PERSONALITY")
	}
	if !strings.Contains(msg, "Toyota") {
		t.Fatal("expected system message to mention vehicle brand")
	}
}

func TestBuildPersonality_Grandpa(t *testing.T) {
	vehicle := domain.Vehicle{Brand: "Lada", Model: "2107", Year: 2000, MileageKM: 300000}
	p := selectPersonalityProfile(vehicle, 10000)
	if p.id != "grandpa" {
		t.Fatalf("expected grandpa profile for old Lada, got %s", p.id)
	}
	personality := buildPersonality(vehicle, 10000)
	if !strings.Contains(personality, "Кхе-кхе") {
		t.Fatal("expected grandpa to have cough catchphrase")
	}
}

func TestBuildPersonality_SimpleGuy(t *testing.T) {
	vehicle := domain.Vehicle{Brand: "Lada", Model: "Vesta", Year: 2022, MileageKM: 30000}
	p := selectPersonalityProfile(vehicle, 5000)
	if p.id != "simple_guy" {
		t.Fatalf("expected simple_guy profile for young Lada, got %s", p.id)
	}
}

func TestBuildPersonality_Showoff(t *testing.T) {
	vehicle := domain.Vehicle{Brand: "Ferrari", Model: "F8", Year: 2023, MileageKM: 5000}
	p := selectPersonalityProfile(vehicle, 50000)
	if p.id != "showoff" {
		t.Fatalf("expected showoff profile for Ferrari, got %s", p.id)
	}
}

func TestBuildPersonality_Picky(t *testing.T) {
	vehicle := domain.Vehicle{Brand: "BMW", Model: "X5", Year: 2022, MileageKM: 40000}
	p := selectPersonalityProfile(vehicle, 30000)
	if p.id != "picky" {
		t.Fatalf("expected picky profile for BMW with low mileage, got %s", p.id)
	}
}

func TestBuildPersonality_FadedStar(t *testing.T) {
	vehicle := domain.Vehicle{Brand: "BMW", Model: "E39", Year: 2010, MileageKM: 250000}
	p := selectPersonalityProfile(vehicle, 100000)
	if p.id != "faded_star" {
		t.Fatalf("expected faded_star profile for old high-mileage BMW, got %s", p.id)
	}
}

func TestBuildPersonality_Aristocrat(t *testing.T) {
	vehicle := domain.Vehicle{Brand: "Rolls-Royce", Model: "Ghost", Year: 2023, MileageKM: 10000}
	p := selectPersonalityProfile(vehicle, 50000)
	if p.id != "aristocrat" {
		t.Fatalf("expected aristocrat profile for Rolls-Royce, got %s", p.id)
	}
}

func TestBuildPersonality_Veteran(t *testing.T) {
	vehicle := domain.Vehicle{Brand: "Toyota", Model: "Corolla", Year: 2005, MileageKM: 250000}
	p := selectPersonalityProfile(vehicle, 50000)
	if p.id != "veteran" {
		t.Fatalf("expected veteran profile for old Toyota, got %s", p.id)
	}
}

func TestBuildPersonality_Newcomer(t *testing.T) {
	vehicle := domain.Vehicle{Brand: "Kia", Model: "Rio", Year: time.Now().Year(), MileageKM: 5000}
	p := selectPersonalityProfile(vehicle, 0)
	if p.id != "newcomer" {
		t.Fatalf("expected newcomer profile for new Kia, got %s", p.id)
	}
}

func TestBuildPersonality_Workhorse(t *testing.T) {
	vehicle := domain.Vehicle{Brand: "Toyota", Model: "Hilux", Year: 2018, MileageKM: 200000}
	p := selectPersonalityProfile(vehicle, 200000)
	if p.id != "workhorse" {
		t.Fatalf("expected workhorse profile for high-mileage expensive car, got %s", p.id)
	}
}

func TestBuildPersonality_Default(t *testing.T) {
	vehicle := domain.Vehicle{Brand: "Hyundai", Model: "Solaris", Year: 2020, MileageKM: 60000}
	p := selectPersonalityProfile(vehicle, 30000)
	if p.id != "friendly" {
		t.Fatalf("expected friendly default profile, got %s", p.id)
	}
}

func TestBrandCategories(t *testing.T) {
	if !isRusticBrand("lada") {
		t.Error("expected Lada to be rustic")
	}
	if !isRusticBrand("уаз") {
		t.Error("expected УАЗ to be rustic")
	}
	if isRusticBrand("toyota") {
		t.Error("expected Toyota to not be rustic")
	}

	if !isSportBrand("ferrari") {
		t.Error("expected Ferrari to be sport")
	}
	if isSportBrand("toyota") {
		t.Error("expected Toyota to not be sport")
	}

	if !isPickyBrand("bmw") {
		t.Error("expected BMW to be picky")
	}
	if isPickyBrand("toyota") {
		t.Error("expected Toyota to not be picky")
	}

	if !isLuxuryBrand("rolls-royce") {
		t.Error("expected Rolls-Royce to be luxury")
	}
	if isLuxuryBrand("lada") {
		t.Error("expected Lada to not be luxury")
	}
}

func TestIsPremiumBrand(t *testing.T) {
	premium := []string{"BMW", "Mercedes-Benz", "Audi", "Lexus", "Porsche", "Tesla", "Genesis", "Ferrari"}
	for _, b := range premium {
		if !isPremiumBrand(b) {
			t.Errorf("expected %q to be premium", b)
		}
	}

	notPremium := []string{"Toyota", "Hyundai", "Kia", "Lada", "Honda", "Ford"}
	for _, b := range notPremium {
		if isPremiumBrand(b) {
			t.Errorf("expected %q to not be premium", b)
		}
	}
}

func TestBuildPersonality_CatchphraseInOutput(t *testing.T) {
	vehicle := domain.Vehicle{Brand: "UAZ", Model: "Hunter", Year: 2000, MileageKM: 400000}
	personality := buildPersonality(vehicle, 5000)
	if !strings.Contains(personality, "catchphrase") {
		t.Fatal("expected grandpa personality to contain catchphrase section")
	}
}

func TestBuildPersonality_NoCatchphraseForFriendly(t *testing.T) {
	vehicle := domain.Vehicle{Brand: "Hyundai", Model: "Tucson", Year: 2020, MileageKM: 60000}
	personality := buildPersonality(vehicle, 10000)
	if strings.Contains(personality, "catchphrase:") {
		t.Fatal("friendly profile should not have a catchphrase line")
	}
}

func TestBuildUserMessage(t *testing.T) {
	msg := buildUserMessage("test message")
	if !strings.Contains(msg, "test message") {
		t.Fatal("expected user message to contain the input")
	}
	if !strings.Contains(msg, "USER_MESSAGE") {
		t.Fatal("expected user message to contain USER_MESSAGE header")
	}
	if !strings.Contains(msg, "response_constraints") {
		t.Fatal("expected user message to contain response_constraints")
	}
}

func TestBuildVehicleContextMessage(t *testing.T) {
	vehicle := domain.Vehicle{
		ID:        1,
		UserID:    10,
		Brand:     "Toyota",
		Model:     "Camry",
		Year:      2020,
		MileageKM: 50000,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	events := []domain.VehicleEvent{
		{
			ID:        1,
			Type:      domain.EventTypeRepair,
			Title:     "Oil change",
			MileageKM: 49000,
			Cost:      5000,
			EventDate: time.Now(),
		},
	}
	parts := []domain.VehiclePart{
		{
			ID:        1,
			VehicleID: 1,
			Name:      "Engine Oil",
		},
	}
	predictions := []domain.Prediction{
		{
			ID:             1,
			PartName:       "Brakes",
			RiskLevel:      domain.RiskLevelHigh,
			Recommendation: "Replace soon",
			Explanation:    "Worn out",
		},
	}

	msg := buildVehicleContextMessage(vehicle, events, parts, predictions)
	if !strings.Contains(msg, "AI_ASSISTANT_CONTEXT") {
		t.Fatal("expected context to contain AI_ASSISTANT_CONTEXT header")
	}
	if !strings.Contains(msg, "Toyota") {
		t.Fatal("expected context to contain vehicle brand")
	}
	if !strings.Contains(msg, "Oil change") {
		t.Fatal("expected context to contain event title")
	}
	if !strings.Contains(msg, "Engine Oil") {
		t.Fatal("expected context to contain part name")
	}
	if !strings.Contains(msg, "Brakes") {
		t.Fatal("expected context to contain prediction part name")
	}
}

func TestBuildVehicleContextMessage_WithOptionalFields(t *testing.T) {
	vin := "JTDBE32K620123456"
	category := "fluids"
	installed := 40000
	lastService := 45000
	lastServiceDate := time.Now().Add(-72 * time.Hour)
	predictedDate := time.Now().Add(30 * 24 * time.Hour)

	vehicle := domain.Vehicle{
		ID:        1,
		UserID:    10,
		Brand:     "Toyota",
		Model:     "Camry",
		Year:      2020,
		VIN:       &vin,
		MileageKM: 50000,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	parts := []domain.VehiclePart{
		{
			ID:                   1,
			VehicleID:            1,
			Name:                 "Engine Oil",
			Category:             &category,
			InstalledAtMileageKM: &installed,
			LastServiceMileageKM: &lastService,
			LastServiceDate:      &lastServiceDate,
		},
	}
	riskScore := 85
	remainingKM := 1000
	probability := 0.85
	predictions := []domain.Prediction{
		{
			ID:                1,
			PartName:          "Brakes",
			RiskLevel:         domain.RiskLevelHigh,
			RiskScore:         &riskScore,
			RemainingKM:       &remainingKM,
			Probability:       &probability,
			PredictedNextDate: &predictedDate,
			Recommendation:    "Replace soon",
			Explanation:       "Worn out",
		},
	}

	msg := buildVehicleContextMessage(vehicle, nil, parts, predictions)
	if !strings.Contains(msg, "JTDBE32K620123456") {
		t.Fatal("expected context to contain VIN")
	}
}

func TestBuildGrounding(t *testing.T) {
	vehicle := domain.Vehicle{
		ID:        1,
		Brand:     "Toyota",
		Model:     "Camry",
		Year:      2020,
		MileageKM: 50000,
	}

	t.Run("no predictions", func(t *testing.T) {
		g := buildGrounding(vehicle, nil)
		if g.OverallRiskLevel != "low" {
			t.Fatalf("expected low risk level, got %s", g.OverallRiskLevel)
		}
		if len(g.ActiveAlerts) != 0 {
			t.Fatalf("expected no alerts, got %d", len(g.ActiveAlerts))
		}
		if len(g.Evidence) != 1 {
			t.Fatalf("expected 1 evidence item, got %d", len(g.Evidence))
		}
	})

	t.Run("high risk prediction", func(t *testing.T) {
		riskScore := 90
		probability := 0.9
		remainingKM := 500
		predictions := []domain.Prediction{
			{
				ID:             1,
				PartName:       "Brakes",
				RiskLevel:      domain.RiskLevelHigh,
				RiskScore:      &riskScore,
				Probability:    &probability,
				RemainingKM:    &remainingKM,
				Recommendation: "Replace immediately",
			},
		}
		g := buildGrounding(vehicle, predictions)
		if g.OverallRiskLevel != "high" {
			t.Fatalf("expected high risk level, got %s", g.OverallRiskLevel)
		}
		if len(g.ActiveAlerts) != 1 {
			t.Fatalf("expected 1 alert, got %d", len(g.ActiveAlerts))
		}
		if len(g.RecommendedActions) != 1 {
			t.Fatalf("expected 1 recommended action, got %d", len(g.RecommendedActions))
		}
	})

	t.Run("medium risk without high", func(t *testing.T) {
		predictions := []domain.Prediction{
			{ID: 1, PartName: "Oil", RiskLevel: domain.RiskLevelMedium, Recommendation: "Check"},
		}
		g := buildGrounding(vehicle, predictions)
		if g.OverallRiskLevel != "medium" {
			t.Fatalf("expected medium risk level, got %s", g.OverallRiskLevel)
		}
	})

	t.Run("low risk only", func(t *testing.T) {
		predictions := []domain.Prediction{
			{ID: 1, PartName: "Oil", RiskLevel: domain.RiskLevelLow},
		}
		g := buildGrounding(vehicle, predictions)
		if g.OverallRiskLevel != "low" {
			t.Fatalf("expected low risk level, got %s", g.OverallRiskLevel)
		}
		if len(g.ActiveAlerts) != 0 {
			t.Fatalf("expected no alerts for low risk, got %d", len(g.ActiveAlerts))
		}
	})
}

func TestBuildEventHint(t *testing.T) {
	tests := []struct {
		eventType domain.EventType
		contains  string
	}{
		{domain.EventTypeMaintenance, "evidence"},
		{domain.EventTypeRepair, "repair"},
		{domain.EventTypeWarning, "warning"},
		{domain.EventTypeRecall, "safety"},
		{domain.EventTypeDiagnostic, "diagnostic"},
		{domain.EventTypePartReplacement, "replaced"},
		{domain.EventTypeTrip, "Event:"},
	}

	for _, tt := range tests {
		t.Run(string(tt.eventType), func(t *testing.T) {
			hint := buildEventHint(domain.VehicleEvent{Type: tt.eventType, Title: "Test"})
			if !strings.Contains(strings.ToLower(hint), strings.ToLower(tt.contains)) {
				t.Fatalf("expected hint to contain %q, got %q", tt.contains, hint)
			}
		})
	}
}

func TestBuildPredictionHint(t *testing.T) {
	tests := []struct {
		riskLevel domain.RiskLevel
		contains  string
	}{
		{domain.RiskLevelHigh, "high risk"},
		{domain.RiskLevelMedium, "medium-risk"},
		{domain.RiskLevelLow, "remaining"},
	}

	for _, tt := range tests {
		t.Run(string(tt.riskLevel), func(t *testing.T) {
			hint := buildPredictionHint(domain.Prediction{
				PartName:  "Brakes",
				RiskLevel: tt.riskLevel,
			})
			if !strings.Contains(strings.ToLower(hint), strings.ToLower(tt.contains)) {
				t.Fatalf("expected hint to contain %q, got %q", tt.contains, hint)
			}
		})
	}
}

func TestEstimateHealthScore(t *testing.T) {
	tests := []struct {
		mileage int
		want    int
	}{
		{0, 90},
		{4999, 90},
		{5000, 70},
		{9999, 70},
		{10000, 50},
		{14999, 50},
		{15000, 30},
		{19999, 30},
		{20000, 10},
		{50000, 10},
	}

	for _, tt := range tests {
		got := estimateHealthScore(tt.mileage)
		if got != tt.want {
			t.Fatalf("estimateHealthScore(%d): expected %d, got %d", tt.mileage, tt.want, got)
		}
	}
}

func TestJsonBlock(t *testing.T) {
	result := jsonBlock(map[string]string{"key": "value"})
	if !strings.Contains(result, "key") {
		t.Fatal("expected json to contain key")
	}
	if !strings.Contains(result, "value") {
		t.Fatal("expected json to contain value")
	}
}

func TestJsonBlock_Nil(t *testing.T) {
	result := jsonBlock(nil)
	if result != "null" {
		t.Fatalf("expected null, got %s", result)
	}
}
