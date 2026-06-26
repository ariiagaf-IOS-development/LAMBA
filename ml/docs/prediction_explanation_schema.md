# Prediction Explanation Schema

## Goal

Define a structured explanation format for ML maintenance predictions. The format is attached to each prediction as `explanation_details` while keeping the existing `explanation` string for backward compatibility with the current backend domain model.

## Payload Shape

```json
{
  "explanation_text": "For Engine oil, model maintenance-risk-baseline-v0.1 (random_forest) predicts medium risk: 60/100. Prediction confidence is 74.5%, and the estimated distance until the next service is about 3,503 km.",
  "confidence": "Medium confidence",
  "confidence_qualifier": "medium",
  "confidence_score": 0.745,
  "factors": [
    {
      "name": "km_since_last_service",
      "value": "4500 km",
      "impact": "medium",
      "weight": 0.4,
      "description": "Distance since the last service increases the chance of upcoming maintenance."
    }
  ],
  "recommended_action": "Engine oil should be checked soon."
}
```

## Fields

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `explanation_text` | string | Yes | Human-readable explanation of the model output. |
| `confidence` | string | Yes | UI-friendly confidence label. |
| `confidence_qualifier` | enum | Yes | Machine-readable confidence bucket: `low`, `medium`, or `high`. |
| `confidence_score` | number | Yes | Normalized confidence score from `0` to `1`. |
| `factors` | array | Yes | Ranked explanation factors used by frontend and AI Assistant. |
| `recommended_action` | string | Yes | Clear next action for the user. |

## Confidence Qualifiers

| Qualifier | Label | Rule |
| --- | --- | --- |
| `high` | `High confidence` | `confidence_score >= 0.75` |
| `medium` | `Medium confidence` | `0.55 <= confidence_score < 0.75` |
| `low` | `Low confidence` | `confidence_score < 0.55` |

## Factor Fields

| Field | Type | Description |
| --- | --- | --- |
| `name` | string | Stable machine-readable factor name. |
| `value` | string | Display-safe value used in the explanation. |
| `impact` | enum | Risk impact of this factor: `low`, `medium`, or `high`. |
| `weight` | number | Relative explanation weight from `0` to `1`. |
| `description` | string | Human-readable meaning of the factor. |

## Generated Explanation Rules

| Model value | Explanation conversion |
| --- | --- |
| `risk_level` | Converted to readable English labels: `low`, `medium`, or `high`. |
| `probability` | Converted to a percentage string, for example `0.745` -> `74.5%`. |
| `remaining_km` | Converted to readable distance, for example `3503` -> `about 3,503 km`. |

Required top factors:

| Factor | Source |
| --- | --- |
| `km_since_last_service` | `km_since_last_maintenance` feature. |
| `driving_profile` | Vehicle `usage_type`. |
| `community_data` | Baseline comparison with similar demo-data vehicles. |

## Integration Notes

- ML responses include `explanation_details` inside every prediction item.
- Existing fields `explanation` and `recommendation` remain unchanged for backend compatibility.
- Backend services that do not yet persist the structured explanation can safely ignore `explanation_details`.
- Frontend and AI Assistant can consume `explanation_details.confidence`, `factors`, and `recommended_action` directly.

## Files

| File | Purpose |
| --- | --- |
| `ml/predictions/prediction_explanation_schema.json` | Machine-readable JSON Schema. |
| `ml/predictions/schemas.py` | Pydantic response schema. |
| `ml/predictions/example_model_predictions.json` | Example model output. |
| `ml/predictions/fallback_examples.json` | Example fallback outputs. |
