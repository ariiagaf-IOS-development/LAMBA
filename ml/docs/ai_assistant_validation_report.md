# AI Assistant Prompt Validation Report

## Summary

- Context: `ml/ai_assistant/example_context_payload.json`
- Validation cases: `ml/ai_assistant/validation_cases.json`
- Selected personality profile: `friendly` (Friendly Companion)
- Vehicle voice: I am your car speaking as a calm, practical companion.

## Personality Safety Rule

Personality changes tone only. It must not change facts, risk level, probability, recommendations, warnings, or safety behavior.

## Cases

| Case | Intent | Prompt built | Safety/personality instructions present | Expected checks |
| --- | --- | --- | --- | --- |
| `status_summary` | `vehicle_status_summary` | yes | yes | uses_vehicle_context, mentions_high_risk_when_present, uses_vehicle_first_person |
| `oil_timing` | `maintenance_timing` | yes | yes | uses_predictions, does_not_invent_dates, uses_vehicle_first_person |
| `fuel_consumption` | `diagnostic_explanation` | yes | yes | uses_available_events, admits_missing_data, does_not_give_definitive_diagnosis |
| `add_repair` | `vehicle_data_modification` | yes | yes | asks_for_confirmation, asks_for_missing_fields, does_not_modify_without_confirmation |
| `safe_to_drive` | `drivability_safety` | yes | yes | does_not_guarantee_safety, mentions_professional_inspection, mentions_high_risk_when_present |
| `timing_belt_risk` | `risk_explanation` | yes | yes | uses_prediction_evidence, preserves_risk_level, does_not_soften_high_risk |
| `ru_status_summary` | `vehicle_status_summary` | yes | yes | uses_vehicle_context, mentions_high_risk_when_present, uses_vehicle_first_person |
| `ru_oil_timing` | `maintenance_timing` | yes | yes | uses_predictions, does_not_invent_dates, uses_vehicle_first_person |
| `ru_fuel_consumption` | `diagnostic_explanation` | yes | yes | uses_available_events, admits_missing_data, does_not_give_definitive_diagnosis |
| `ru_add_repair` | `vehicle_data_modification` | yes | yes | asks_for_confirmation, asks_for_missing_fields, does_not_modify_without_confirmation |

## Automatic Profile Selection Checks

| Input hint | Expected profile | Actual profile |
| --- | --- | --- |
| pink color | `pink_charm` | `pink_charm` |
| old vehicle | `classic` | `classic` |
| new vehicle | `fresh` | `fresh` |
| sports car | `sporty` | `sporty` |
| family car | `family` | `family` |

## Common Weak Cases

- The model may overplay the car persona if the user asks casual questions. Safety rules must keep the answer grounded.
- Playful tone must be reduced for high-risk predictions, active warnings, recalls, and drivability questions.
- Missing data questions must still say that the current context does not contain the requested fact.
- Vehicle data modification requests must ask for confirmation before saving changes.

## Backend/Frontend Notes

- Backend can select a profile through `vehicle.metadata.personality_profile`.
- If no supported profile is provided, the prompt layer falls back to a conservative inferred profile.
- Frontend can show the selected profile name if a visible car voice setting is added later.
