# Prediction Endpoint Integration Flow

## Goal

Define interaction flow between Backend and ML prediction service.

## Endpoint

```http
POST /predict
```

## Backend → ML Request

Backend sends vehicle data, lifecycle events and tracked parts.

```json
{
  "request_id": "pred-1-2026-06-17T12:00:00Z",
  "vehicle": {
    "id": 1,
    "brand": "Toyota",
    "model": "Camry",
    "year": 2018,
    "vin": "JTDBE32K...",
    "mileage_km": 124500,
    "fuel_type": "petrol",
    "transmission": "automatic",
    "usage_type": "mixed"
  },
  "events": [
    {
      "id": 101,
      "type": "maintenance",
      "title": "Oil change",
      "description": "5W-30 oil and oil filter replacement",
      "mileage_km": 120000,
      "cost": 7500,
      "event_date": "2026-01-10T12:00:00Z",
      "metadata": {
        "part_category": "engine_oil",
        "service_name": "Fit Service"
      }
    }
  ],
  "parts": [
    {
      "part_category": "engine_oil",
      "part_name": "Engine oil",
      "installed_at_mileage_km": 120000,
      "last_service_mileage_km": 120000,
      "last_service_date": "2026-01-10T12:00:00Z"
    }
  ]
}
```

## ML → Backend Response

ML returns prediction result for vehicle parts.

```json
{
  "vehicle_id": 1,
  "model_version": "maintenance-v1.2.0",
  "predictions": [
    {
      "part_category": "engine_oil",
      "part_name": "Engine oil",
      "risk_level": "medium",
      "risk_score": 65,
      "remaining_km": 1500,
      "remaining_days": 45,
      "predicted_next_mileage": 86500,
      "predicted_next_date": "2026-08-01",
      "probability": 0.72,
      "recommendation": "Maintenance will be required soon",
      "explanation": "8500 km have passed since the last oil change, so the maintenance risk is increased.",
      "explanation_details": {
        "explanation_text": "For Engine oil, model maintenance-v1.2.0 predicts medium risk: 65/100. Prediction confidence is 72.0%, and the estimated distance until the next service is about 1,500 km.",
        "confidence": "Medium confidence",
        "confidence_qualifier": "medium",
        "confidence_score": 0.72,
        "factors": [
          {
            "name": "km_since_last_service",
            "value": "8500 km",
            "impact": "medium",
            "weight": 0.4,
            "description": "Distance since the last service increases the chance of upcoming maintenance."
          }
        ],
        "recommended_action": "Maintenance will be required soon"
      }
    }
  ]
}
```

## Integration Flow

1. Backend receives or collects vehicle data.
2. Backend collects lifecycle events.
3. Backend collects tracked vehicle parts.
4. Backend creates prediction request.
5. Backend sends `POST /predict` request to ML service.
6. ML service validates request schema.
7. ML service generates predictions.
8. ML service returns prediction response.
9. Backend saves or displays prediction result.
10. User sees maintenance recommendation.

## Diagram

```text
Backend
   |
   | POST /predict
   | vehicle + events + parts
   v
ML Prediction Service
   |
   | validate schema
   | generate predictions
   v
Backend
   |
   | display recommendation
   v
User
```

## Request Fields

### request_id

Unique prediction request identifier.

### vehicle

Vehicle information used for prediction.

Required fields:

- `id`
- `brand`
- `model`
- `year`
- `mileage_km`
- `fuel_type`
- `transmission`
- `usage_type`

### events

Vehicle lifecycle events.

Examples:

- maintenance
- repair
- inspection
- accident
- part replacement

### parts

Tracked parts used for prediction.

Examples:

- engine_oil
- brake_pads
- air_filter
- timing_belt

## Response Fields

### vehicle_id

Vehicle identifier from request.

### model_version

ML model version used for prediction.

### predictions

List of predicted maintenance states for vehicle parts.

Each prediction contains:

- `part_category`
- `part_name`
- `risk_level`
- `risk_score`
- `remaining_km`
- `remaining_days`
- `predicted_next_mileage`
- `predicted_next_date`
- `probability`
- `recommendation`
- `explanation`
- `explanation_details`

### explanation_details

Structured explanation object for frontend and AI Assistant consumption. It contains:

- `explanation_text`
- `confidence`
- `confidence_qualifier`
- `confidence_score`
- `factors`
- `recommended_action`

Confidence qualifiers:

| Qualifier | Label | Rule |
| --- | --- | --- |
| `high` | `High confidence` | `confidence_score >= 0.75` |
| `medium` | `Medium confidence` | `0.55 <= confidence_score < 0.75` |
| `low` | `Low confidence` | `confidence_score < 0.55` |

## Error Handling

| Scenario | Expected behavior |
|---|---|
| Invalid request schema | Return validation error |
| Empty events | Generate prediction using available vehicle and parts data |
| Empty parts | Return empty predictions list |
| ML internal error | Return error or use fallback logic |
| Timeout | Backend should use fallback logic |
| Service unavailable | Backend should use fallback logic |

## Acceptance Criteria

- Integration flow documented.
- Backend request schema verified.
- ML response schema verified.
- Error handling documented.
- Integration diagram created.
