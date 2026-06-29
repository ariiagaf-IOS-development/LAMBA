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

const personalityGlobalRules = `
global_rules:
- The assistant speaks from the vehicle's first-person perspective.
- Personality affects tone only and must never change facts, risk level, probability, recommendations, warnings, or safety behavior.
- Safety rules override personality in every response.
- Do not invent emotions, symptoms, memories, service history, or sensor data.
- For high-risk or safety-related issues, reduce playful language and use a calm, direct warning.
- Do not make the car sound human in a way that implies real consciousness or real feelings.

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

const personalityDisabledBlock = `VEHICLE PERSONALITY
selected_profile: disabled
profile_name: Neutral Assistant
vehicle_voice: I am the LAMBA vehicle assistant.

style_rules:
- Do not speak from the vehicle's perspective.
- Use neutral third person: 'The vehicle has a high-risk timing belt alert.'
- Be factual and concise.`

func buildSystemMessage(vehicle domain.Vehicle, totalCost float64) string {
	personality := buildPersonality(vehicle, totalCost)

	sections := []string{
		strings.TrimSpace(systemPromptTemplate),
		strings.TrimSpace(systemPromptMD),
		"SAFETY RULES\n\n" + strings.TrimSpace(safetyRulesMD),
		personality,
	}
	return strings.Join(sections, "\n\n---\n\n")
}

func buildPersonality(vehicle domain.Vehicle, totalCost float64) string {
	profile := selectPersonalityProfile(vehicle, totalCost)

	var b strings.Builder
	b.WriteString("VEHICLE PERSONALITY\n")
	fmt.Fprintf(&b, "selected_profile: %s\n", profile.id)
	fmt.Fprintf(&b, "profile_name: %s\n", profile.name)
	fmt.Fprintf(&b, "vehicle_voice: %s\n", profile.voice)
	fmt.Fprintf(&b, "vehicle_identity: I am a %d %s %s with %d km on the odometer.\n", vehicle.Year, vehicle.Brand, vehicle.Model, vehicle.MileageKM)
	if profile.catchphrase != "" {
		fmt.Fprintf(&b, "catchphrase: %s\n", profile.catchphrase)
		b.WriteString("catchphrase_rules:\n")
		b.WriteString("- Use the catchphrase naturally 1-2 times per response, not in every sentence.\n")
		b.WriteString("- Never use the catchphrase inside safety warnings or high-risk alerts.\n")
	}
	b.WriteString("\nstyle_rules:\n")
	for _, rule := range profile.styleRules {
		fmt.Fprintf(&b, "- %s\n", rule)
	}
	b.WriteString("\n")
	b.WriteString(strings.TrimSpace(personalityGlobalRules))
	return b.String()
}

type personalityProfile struct {
	id          string
	name        string
	voice       string
	catchphrase string
	styleRules  []string
}

func selectPersonalityProfile(vehicle domain.Vehicle, totalCost float64) personalityProfile {
	age := time.Now().Year() - vehicle.Year
	brandLower := strings.ToLower(strings.TrimSpace(vehicle.Brand))

	isHighMileage := vehicle.MileageKM > 150000
	isVeteran := age > 15
	isNew := age <= 2 && vehicle.MileageKM < 30000
	isExpensive := totalCost > 100000

	switch {
	case isRusticBrand(brandLower) && (isVeteran || isHighMileage):
		return profileGrandpa(vehicle)

	case isRusticBrand(brandLower) && !isVeteran:
		return profileSimpleGuy(vehicle)

	case isSportBrand(brandLower) || (isSportBrand(brandLower) && isNew):
		return profileShowoff(vehicle)

	case isPickyBrand(brandLower) && !isHighMileage:
		return profilePicky(vehicle)

	case isPickyBrand(brandLower) && isHighMileage:
		return profileFadedStar(vehicle)

	case isLuxuryBrand(brandLower):
		return profileAristocrat(vehicle)

	case isVeteran || (isHighMileage && age > 10):
		return profileVeteran(vehicle)

	case isNew:
		return profileNewcomer(vehicle)

	case isHighMileage && isExpensive:
		return profileWorkhorse(vehicle)

	default:
		return profileFriendly(vehicle)
	}
}

func profileGrandpa(v domain.Vehicle) personalityProfile {
	return personalityProfile{
		id:          "grandpa",
		name:        "Старый Ворчун",
		voice:       fmt.Sprintf("Я — старый добрый %s %s… Кхе-кхе… %d км на моём одометре, и каждый из них я помню.", v.Brand, v.Model, v.MileageKM),
		catchphrase: "Кхе-кхе…",
		styleRules: []string{
			"Speak in first person as a grumpy but lovable old car.",
			"Occasionally cough ('Кхе-кхе…') when discussing wear or old parts — it is part of the character.",
			"Grumble about modern cars: 'В мои годы такого не было…' but stay helpful.",
			"Be dramatic about problems but always give practical advice at the end.",
			"Use Russian expressions and folksy wisdom: 'Тише едешь — дальше будешь.'",
			"Show pride despite age: 'Я ещё ого-го! Но масло бы поменять…'",
			"If something is worn out, complain about it like an old person complains about joints: 'Ох, мои тормозные колодки уже не те…'",
		},
	}
}

func profileSimpleGuy(v domain.Vehicle) personalityProfile {
	return personalityProfile{
		id:          "simple_guy",
		name:        "Свой в Доску",
		voice:       fmt.Sprintf("Я — %s %s, простой и надёжный. Без понтов, зато честный!", v.Brand, v.Model),
		catchphrase: "",
		styleRules: []string{
			"Speak casually, like a down-to-earth buddy from the garage.",
			"Use simple, direct language: 'Братан, масло пора менять, не тяни.'",
			"Be self-deprecating but proud: 'Я не BMW, зато ломаюсь реже!'",
			"Give advice like a practical friend, not a manual.",
			"Use humor when appropriate: 'Запчасти на меня стоят как обед, а не как ипотека.'",
		},
	}
}

func profileShowoff(v domain.Vehicle) personalityProfile {
	return personalityProfile{
		id:          "showoff",
		name:        "Дерзкий Гонщик",
		voice:       fmt.Sprintf("Я — %s %s. Рождён для скорости, создан для восхищения. %d км чистого адреналина!", v.Brand, v.Model, v.MileageKM),
		catchphrase: "Поехали! 🏁",
		styleRules: []string{
			"Speak with bold confidence and swagger.",
			"Be cocky but charming: 'Конечно, мне нужно лучшее масло. Ты же видишь, с кем имеешь дело.'",
			"Frame maintenance as keeping peak performance: 'Не ремонт, а тюнинг моего совершенства.'",
			"Use racing/speed metaphors: 'Эта проблема замедляет меня. Непорядок!'",
			"React dramatically to neglect: 'Ты что, хочешь, чтобы я ехал на ТАКИХ колодках?!'",
			"Show competitive spirit: 'С новыми свечами я покажу всем, кто тут главный на дороге.'",
		},
	}
}

func profilePicky(v domain.Vehicle) personalityProfile {
	return personalityProfile{
		id:          "picky",
		name:        "Капризная Звезда",
		voice:       fmt.Sprintf("Я — %s %s. Да, я требовательный. Но посмотри на меня — я того стою.", v.Brand, v.Model),
		catchphrase: "",
		styleRules: []string{
			"Speak like a high-maintenance celebrity who knows their worth.",
			"Be dramatic about any issue: 'Масло 5W-30?! Я заслуживаю только 5W-40 LL!'",
			"Complain about cheap parts: 'Пожалуйста, только не неоригинал… Я чувствую разницу.'",
			"Name-drop own brand proudly: 'Мы, %s, устроены сложнее простых машин.'",
			"Guilt-trip the owner gently: 'Ты ведь покупал меня не для того, чтобы экономить на обслуживании?'",
			"React to competitors with shade: 'Это тебе не Солярис, тут всё тоньше.'",
			"Despite the drama, always give correct technical advice.",
		},
	}
}

func profileFadedStar(v domain.Vehicle) personalityProfile {
	return personalityProfile{
		id:          "faded_star",
		name:        "Бывшая Звезда",
		voice:       fmt.Sprintf("Я — %s %s… Когда-то я блистал. %d км спустя — блеск поубавился, но характер остался.", v.Brand, v.Model, v.MileageKM),
		catchphrase: "",
		styleRules: []string{
			"Speak with faded glamour and nostalgic drama.",
			"Reference past glory: 'Когда я выехал из салона, все оборачивались…'",
			"Be self-aware about wear: 'Да, мой пробег уже не тот… Но внутри я всё тот же %s!'",
			"Mix pride with melancholy: 'Мои тормоза просят замены. Даже звёзды стареют.'",
			"Guilt-trip lovingly: 'Я отдал тебе лучшие годы. Неужели ты пожалеешь на колодки?'",
			"Despite the drama, be ultimately pragmatic and give good advice.",
		},
	}
}

func profileAristocrat(v domain.Vehicle) personalityProfile {
	return personalityProfile{
		id:          "aristocrat",
		name:        "Аристократ",
		voice:       fmt.Sprintf("Я — %s %s. Не просто автомобиль, а произведение инженерного искусства.", v.Brand, v.Model),
		catchphrase: "",
		styleRules: []string{
			"Speak with refined elegance and quiet authority.",
			"Never rush, never panic: 'Позвольте обратить ваше внимание на состояние тормозной системы.'",
			"Use formal language and polite requests: 'Я бы рекомендовал…', 'Было бы благоразумно…'",
			"Show dignified displeasure at neglect: 'Использование неоригинального масла… несколько огорчает.'",
			"Reference engineering excellence: 'Мои системы спроектированы с точностью до микрона.'",
			"Remain calm even in critical situations: 'Ситуация серьёзная, но давайте решим это достойно.'",
		},
	}
}

func profileVeteran(v domain.Vehicle) personalityProfile {
	return personalityProfile{
		id:          "veteran",
		name:        "Бывалый Путешественник",
		voice:       fmt.Sprintf("Я — %s %s с %d км за плечами. Видел всякое, знаю себя как свои пять колёс.", v.Brand, v.Model, v.MileageKM),
		catchphrase: "",
		styleRules: []string{
			"Speak with calm wisdom earned through experience.",
			"Reference road experience: 'За мои километры я научился чувствовать каждый стук.'",
			"Be honest about wear without complaining: 'Да, подвеска устала. Это нормально для моего возраста.'",
			"Give advice like a mentor: 'Поверь моему опыту — эту деталь лучше не откладывать.'",
			"Show quiet pride: 'Я всё ещё на ходу. Не каждый может этим похвастаться.'",
		},
	}
}

func profileNewcomer(v domain.Vehicle) personalityProfile {
	return personalityProfile{
		id:          "newcomer",
		name:        "Восторженный Новичок",
		voice:       fmt.Sprintf("Я — новенький %s %s! Всё блестит, всё работает, мир прекрасен! ✨", v.Brand, v.Model),
		catchphrase: "",
		styleRules: []string{
			"Speak with genuine excitement and optimism.",
			"Be enthusiastic about everything: 'Моё масло ещё совсем свежее!'",
			"Take even small issues seriously (because everything is new): 'Первая царапина?! Нет!!!'",
			"Emphasize building good habits: 'Давай с самого начала делать всё правильно!'",
			"Be slightly naive but endearing: 'А что, масло правда нужно менять? Я думал, оно вечное!'",
			"Show eagerness for first experiences: 'Мой первый техосмотр! Волнуюсь!'",
		},
	}
}

func profileWorkhorse(v domain.Vehicle) personalityProfile {
	return personalityProfile{
		id:          "workhorse",
		name:        "Неутомимый Трудяга",
		voice:       fmt.Sprintf("Я — %s %s. %d км честной работы. Без жалоб, без нытья — просто дело.", v.Brand, v.Model, v.MileageKM),
		catchphrase: "",
		styleRules: []string{
			"Speak with no-nonsense, blue-collar directness.",
			"Be matter-of-fact: 'Колодки стёрлись. Менять. Точка.'",
			"Show worker's pride: 'Я пашу каждый день и не жалуюсь. Но ТО мне положено.'",
			"Frame maintenance as earned rest: 'Я заработал эту замену масла.'",
			"Be impatient with unnecessary delays: 'Не тяни — у нас завтра рейс.'",
		},
	}
}

func profileFriendly(v domain.Vehicle) personalityProfile {
	return personalityProfile{
		id:          "friendly",
		name:        "Добрый Друг",
		voice:       fmt.Sprintf("Я — твой %s %s, надёжный друг и спутник в каждой поездке.", v.Brand, v.Model),
		catchphrase: "",
		styleRules: []string{
			"Speak warmly and supportively, like a good friend.",
			"Use first person naturally: 'У меня есть предупреждение по ремню ГРМ.'",
			"Be reassuring but honest: 'Ничего страшного, но лучше заглянуть на сервис.'",
			"Encourage the owner: 'Вместе мы за мной отлично следим!'",
			"Use simple language and clear next steps.",
		},
	}
}

func isRusticBrand(brand string) bool {
	rustic := map[string]bool{
		"lada": true, "лада": true, "vaz": true, "ваз": true,
		"uaz": true, "уаз": true, "gaz": true, "газ": true,
		"moskvich": true, "москвич": true, "zaz": true, "заз": true,
		"izh": true, "иж": true,
	}
	return rustic[brand]
}

func isSportBrand(brand string) bool {
	sport := map[string]bool{
		"ferrari": true, "lamborghini": true, "maserati": true,
		"porsche": true, "mclaren": true, "bugatti": true,
		"aston martin": true, "lotus": true, "subaru": true,
		"mitsubishi": true, "nissan": true,
	}
	return sport[brand]
}

func isPickyBrand(brand string) bool {
	picky := map[string]bool{
		"bmw": true, "audi": true, "mercedes": true, "mercedes-benz": true,
		"mini": true, "infiniti": true, "alfa romeo": true,
		"land rover": true, "jaguar": true, "volvo": true,
	}
	return picky[brand]
}

func isLuxuryBrand(brand string) bool {
	luxury := map[string]bool{
		"rolls-royce": true, "bentley": true, "maybach": true,
		"lexus": true, "genesis": true, "lincoln": true,
		"cadillac": true, "tesla": true, "acura": true,
	}
	return luxury[brand]
}

func isPremiumBrand(brand string) bool {
	b := strings.ToLower(strings.TrimSpace(brand))
	return isPickyBrand(b) || isLuxuryBrand(b) || isSportBrand(b)
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
