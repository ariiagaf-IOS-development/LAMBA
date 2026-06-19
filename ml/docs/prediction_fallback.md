# Prediction Service Fallback Logic

## Goal

Ensure prediction functionality remains available when the ML service is unavailable.

## Scope

This document describes fallback behavior for prediction service integration.

The actual rule-based health calculation logic is out of scope for this document and should be implemented separately in the parts health model module.

## When fallback is used

Fallback logic should be used when:

- ML service timeout occurs.
- ML service returns `503 Service Unavailable`.
- ML service is unreachable.
- ML service returns an invalid response.
- ML response does not match the prediction API contract.

## Fallback Strategy

Fallback strategy should preserve the same response format as the regular ML prediction response.

This means Backend should receive a valid prediction response even if the ML service is unavailable.

Fallback response must follow the prediction API schema:

```json
{
  "vehicle_id": 1,
  "model_version": "fallback-maintenance-v1.0.0",
  "predictions": [
    {
      "part_category": "engine_oil",
      "part_name": "Engine oil",
      "risk_level": "medium",
      "risk_score": 65,
      "remaining_km": 1500,
      "remaining_days": 45,
      "predicted_next_mileage": 130000,
      "predicted_next_date": "2026-08-01",
      "probability": 0.65,
      "recommendation": "Maintenance will be required soon.",
      "explanation": "Fallback response is used because ML service is unavailable."
    }
  ]
}