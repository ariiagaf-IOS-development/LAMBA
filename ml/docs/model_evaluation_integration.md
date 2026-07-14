# Model Evaluation and Integration Outputs

## Goal

Evaluate the persisted maintenance risk baseline model and prepare prediction outputs that match the backend prediction contract.

## Generated Outputs

| File | Purpose |
| --- | --- |
| `ml/evaluation/evaluate_model.py` | Evaluates the persisted model artifact on the validation split. |
| `ml/evaluation/metrics.json` | Machine-readable metrics and validation predictions. |
| `ml/evaluation/evaluation_report.md` | Human-readable model quality report. |
| `ml/predictions/model_inference.py` | Generates a backend-compatible prediction response from a prediction request. |
| `ml/predictions/example_model_predictions.json` | Example ML response validated against `PredictionResponseSchema`. |
| `ml/predictions/prediction_client_contract.json` | Backend/ML request and response contract reference. |

## Evaluation Command

```bash
python3 ml/evaluation/evaluate_model.py
```

This command reads:

```text
ml/training/artifacts/maintenance_risk_model.joblib
ml/training/baseline/validation.csv
```

and writes:

```text
ml/evaluation/metrics.json
ml/evaluation/evaluation_report.md
```

## Current Evaluation Summary

| Metric | Value |
| --- | ---: |
| Selected model | `random_forest` |
| Validation rows | 6 |
| Risk accuracy | 0.6667 |
| Risk precision macro | 0.2222 |
| Risk recall macro | 0.3333 |
| Risk F1 macro | 0.2667 |
| Remaining km MAE | 3638.83 km |
| Remaining km RMSE | 5028.73 km |
| Remaining km R2 | -0.7885 |

The validation split is intentionally small. These metrics should be treated as baseline smoke-test metrics, not production-quality estimates.

## Prediction Example Command

```bash
python3 ml/predictions/model_inference.py
```

This command reads:

```text
ml/predictions/example_predict_request.json
ml/training/artifacts/maintenance_risk_model.joblib
```

and writes:

```text
ml/predictions/example_model_predictions.json
```

The generated response is validated by the Pydantic `PredictionResponseSchema` in:

```text
ml/predictions/schemas.py
```

## Backend Compatibility

The generated prediction response follows the same fields used by the backend ML service provider:

| Response field | Backend mapping |
| --- | --- |
| `vehicle_id` | `domain.Prediction.VehicleID` |
| `model_version` | `domain.Prediction.ModelVersion` |
| `part_category` | `domain.Prediction.PartCategory` |
| `part_name` | `domain.Prediction.PartName` |
| `risk_level` | `domain.Prediction.RiskLevel` |
| `risk_score` | `domain.Prediction.RiskScore` |
| `remaining_km` | `domain.Prediction.RemainingKM` |
| `remaining_days` | `domain.Prediction.RemainingDays` |
| `predicted_next_mileage` | `domain.Prediction.PredictedNextMileage` |
| `predicted_next_date` | `domain.Prediction.PredictedNextDate` |
| `probability` | `domain.Prediction.Probability` |
| `recommendation` | `domain.Prediction.Recommendation` |
| `explanation` | `domain.Prediction.Explanation` |

## Integration Notes

- The backend should continue sending `POST /predict` requests as described in `ml/predictions/prediction_client_contract.json`.
- The ML service validates incoming requests with `PredictionRequestSchema`.
- The ML model response is validated with `PredictionResponseSchema`.
- If the model artifact is missing or inference fails, `ml/app.py` keeps the existing fallback behavior.
- The persisted artifact was created with `scikit-learn==1.6.1`; local and CI environments should keep this version to avoid joblib compatibility issues.

## Acceptance Criteria Status

| Criteria | Status |
| --- | --- |
| Metrics calculated and documented | Done: `metrics.json`, `evaluation_report.md` |
| Evaluation report generated | Done: `ml/evaluation/evaluation_report.md` |
| Prediction examples created | Done: `ml/predictions/example_model_predictions.json` |
| Prediction schema compatibility verified | Done: generated via `PredictionResponseSchema` |
| Backend team receives integration examples | Done: this document plus JSON examples |
