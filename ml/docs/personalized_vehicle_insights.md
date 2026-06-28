# Personalized Vehicle Insights Logic

## Goal

Generate short, personalized vehicle insights from `ai-assistant-context-v0.1` data. Insights must be useful for a non-technical vehicle owner, grounded only in provided context, and ready for frontend display.

Related files:

- `ml/ai_assistant/context_schema.json`
- `ml/ai_assistant/example_context_payload.json`
- `ml/insights/frontend_insight_schema.json`

## Context Inputs

The insight generator should read these sections from `context_schema.json`:

| Context section | Used for |
| --- | --- |
| `vehicle` | Vehicle label, current mileage, and optional metadata for personalization. |
| `timeline.events` | Maintenance, repair, warning, diagnostic, recall, refuel, accident, and note history. |
| `parts_health.parts` | Component health, risk level, remaining kilometers, and recommended action. |
| `predictions.items` | ML/rule-based risk, probability, remaining distance or date, and explanation. |
| `grounding.active_alerts` | High-signal warnings already prioritized by backend/ML context assembly. |
| `grounding.recommended_actions` | Safe next actions that can be reused in insight copy. |
| `grounding.evidence` | Source-backed statements that should be preferred for factual claims. |

The generator must not use facts outside the context payload. If a cost, date, DTC code, service record, recall status, or prediction value is missing, the insight should either omit that detail or state that the context does not contain it.

## Frontend Output Schema

Each insight should match `ml/insights/frontend_insight_schema.json`.

```json
{
  "title": "Timing belt needs attention",
  "body": "The current context shows the timing belt is high risk with -500 km remaining. Schedule inspection or replacement soon.",
  "category": "risk_warning",
  "severity": "high"
}
```

Required fields:

| Field | Type | Rule |
| --- | --- | --- |
| `title` | string | Short card title. Avoid technical codes unless the code is the main user-visible fact. |
| `body` | string | Plain-language explanation using only context data. |
| `category` | enum | One of `maintenance_due`, `cost_trend`, `anomaly_alert`, `positive_feedback`, `risk_warning`. |
| `severity` | enum | One of `info`, `low`, `medium`, `high`. |

Optional implementation fields may be added later only after frontend agreement, such as `source_refs`, `action`, `created_at`, or `vehicle_id`.

## Categories

### `maintenance_due`

Use for upcoming or overdue service work.

Primary sources:

- `parts_health.parts[].remaining_km`
- `parts_health.parts[].risk_level`
- `parts_health.parts[].recommendation`
- `predictions.items[].remaining_km`
- `predictions.items[].predicted_next_date`
- maintenance or part replacement events in `timeline.events`

Trigger logic:

- `remaining_km <= 0` means overdue.
- `remaining_km` is positive but near the warning window from the part-health model.
- `risk_level` is `medium` or `high` for a serviceable part.
- `predicted_next_date` exists and is close enough to be actionable.

Severity mapping:

| Condition | Severity |
| --- | --- |
| Overdue critical service or high-risk serviceable part | `high` |
| Upcoming service soon, medium risk, or low remaining distance | `medium` |
| Informational service reminder with low risk | `low` |

Example:

```json
{
  "title": "Oil service is coming up",
  "body": "The context shows about 1,500 km remaining for engine oil. Plan an oil service soon.",
  "category": "maintenance_due",
  "severity": "medium"
}
```

### `cost_trend`

Use for spending patterns based on recorded event costs.

Primary sources:

- `timeline.events[].cost`
- event types `maintenance`, `repair`, `refuel`, `inspection`, `part_replacement`
- event dates and mileage for grouping recent costs

Trigger logic:

- At least two non-zero costs exist and recent total cost increased compared with older records.
- A single high-cost repair or service is present.
- Cost fields are present but all are zero or null, in which case produce an `info` insight only if the UI needs a cost-data state.

Severity mapping:

| Condition | Severity |
| --- | --- |
| Large recent increase or unusually high single cost | `medium` |
| Small recent increase | `low` |
| Costs missing or all zero | `info` |

Do not invent repair prices or market averages. If the context has no real cost data, say that cost history is limited.

Example:

```json
{
  "title": "Cost history is limited",
  "body": "The current context does not include non-zero repair or service costs, so I cannot identify a spending trend yet.",
  "category": "cost_trend",
  "severity": "info"
}
```

### `anomaly_alert`

Use for unusual events or changes that may need attention but are not necessarily model predictions.

Primary sources:

- active warning events in `timeline.events`
- diagnostic events and `metadata.dtc_codes`
- accident, recall, or repeated repair events
- unexpected refuel/fuel efficiency changes when available
- `grounding.active_alerts`

Trigger logic:

- Active warning event exists.
- Diagnostic event contains codes or a result such as `codes_found`.
- Multiple repair events appear for the same system or component.
- Recall event is open or status is not confirmed closed.

Severity mapping:

| Condition | Severity |
| --- | --- |
| Safety-related active warning, open safety recall, accident, brake/tire/steering issue | `high` |
| Active warning or diagnostic issue without high-risk safety marker | `medium` |
| Non-critical anomaly or incomplete data | `low` |

Example:

```json
{
  "title": "Check engine warning needs review",
  "body": "The context includes an active check engine warning and a recent diagnostic scan. A service inspection is recommended before this becomes a bigger issue.",
  "category": "anomaly_alert",
  "severity": "medium"
}
```

### `positive_feedback`

Use for encouraging, factual feedback when the vehicle context shows healthy or recently improved state.

Primary sources:

- recent maintenance or part replacement events
- `parts_health.parts[].risk_level = low`
- high `health_score`
- no active alerts in `grounding.active_alerts`
- stable or low overall risk in `grounding.overall_risk_level`

Trigger logic:

- A maintenance event was recently completed.
- A tracked part is low risk with strong health score.
- Overall risk is low and there are no active alerts.

Severity mapping:

| Condition | Severity |
| --- | --- |
| Positive informational feedback | `info` |
| Low-priority reassurance with minor monitoring note | `low` |

Avoid overpromising. Do not say the vehicle is completely safe or problem-free.

Example:

```json
{
  "title": "Recent oil service is recorded",
  "body": "The context includes a recent oil service record, so future oil recommendations can use that service as evidence.",
  "category": "positive_feedback",
  "severity": "info"
}
```

### `risk_warning`

Use for high-priority risk or prediction messages.

Primary sources:

- `predictions.items[].risk_level`
- `predictions.items[].risk_score`
- `predictions.items[].probability`
- `parts_health.parts[].risk_level`
- `grounding.active_alerts`
- `grounding.recommended_actions`

Trigger logic:

- Any prediction, part health item, or grounding alert is `high`.
- Remaining kilometers are zero or negative for a critical component.
- Prediction probability or risk score indicates strong risk.

Severity mapping:

| Condition | Severity |
| --- | --- |
| High-risk prediction, high-risk part, or high-severity alert | `high` |
| Medium-risk prediction affecting an important component | `medium` |

Risk warnings must use cautious wording: model outputs are estimates, not final diagnoses.

Example:

```json
{
  "title": "High-risk timing belt warning",
  "body": "The model estimates high timing belt risk and the context shows it is overdue. Schedule professional inspection or replacement without delay.",
  "category": "risk_warning",
  "severity": "high"
}
```

## Extraction Flow

1. Load one `ai-assistant-context-v0.1` payload.
2. Validate that required top-level sections exist: `vehicle`, `timeline`, `parts_health`, `predictions`, and `grounding`.
3. Normalize source records into candidate signals:
   - service signals from `parts_health` and maintenance events;
   - cost signals from event `cost` fields;
   - anomaly signals from warning, diagnostic, recall, accident, and repeated repair events;
   - positive signals from recent maintenance and low-risk health;
   - risk signals from predictions, part health, and grounding alerts.
4. Score each candidate by category priority, severity, recency, and source confidence.
5. Deduplicate candidates that describe the same component or event.
6. Generate concise `title` and `body` text from the strongest evidence.
7. Return frontend-compatible insight objects.

Recommended category priority:

1. `risk_warning`
2. `anomaly_alert`
3. `maintenance_due`
4. `cost_trend`
5. `positive_feedback`

This priority should prevent a positive insight from hiding a high-risk issue.

## Grounding Rules

- Prefer `grounding.evidence` statements for factual claims.
- If using `timeline.events`, include only facts present in event fields or metadata.
- If using model outputs, preserve the original risk level, probability, remaining distance, and recommendation.
- Do not convert predictions into certainty.
- Do not invent costs, dates, closed recall status, diagnostic codes, or service records.

## Frontend Display Guidance

Suggested visual treatment:

| Severity | UI treatment |
| --- | --- |
| `high` | Prominent warning card, red/error icon, visible near top. |
| `medium` | Attention card, amber/warning icon. |
| `low` | Standard informational card. |
| `info` | Neutral card or compact note. |

Suggested category icons:

| Category | Icon idea |
| --- | --- |
| `maintenance_due` | wrench/service |
| `cost_trend` | receipt/chart |
| `anomaly_alert` | alert triangle |
| `positive_feedback` | check circle |
| `risk_warning` | shield/warning |

## Acceptance Checklist

- Insight generation logic is documented.
- Categories are defined: `maintenance_due`, `cost_trend`, `anomaly_alert`, `positive_feedback`, `risk_warning`.
- Output format is frontend compatible through `title`, `body`, `category`, and `severity`.
- Logic is grounded in `ml/ai_assistant/context_schema.json`.
- Missing context is handled without unsupported claims.
