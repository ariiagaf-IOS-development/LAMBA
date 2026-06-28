# Maintenance Risk Model Evaluation

## Summary

- Model version: `maintenance-risk-baseline-v0.1`
- Selected model: `random_forest`
- Validation rows: `6`
- Feature count: `22`
- Artifact: `ml/training/artifacts/maintenance_risk_model.joblib`

## Classification Metrics

| Metric | Value |
| --- | ---: |
| Accuracy | 0.6667 |
| Precision macro | 0.2222 |
| Recall macro | 0.3333 |
| F1 macro | 0.2667 |

## Remaining Kilometer Metrics

| Metric | Value |
| --- | ---: |
| MAE | 3638.83 km |
| RMSE | 5028.73 km |
| R2 | -0.7885 |

## Confusion Matrix

Rows are actual labels; columns are predicted labels.

| Actual \ Predicted | low | medium | high |
| --- | ---: | ---: | ---: |
| low | 0 | 1 | 0 |
| medium | 0 | 4 | 0 |
| high | 0 | 1 | 0 |

## Validation Predictions

| Vehicle ID | Actual risk | Predicted risk | Actual remaining km | Predicted remaining km |
| ---: | --- | --- | ---: | ---: |
| 1 | medium | medium | 2637 | 3383 |
| 9 | low | medium | 12000 | 2713 |
| 10 | high | medium | 0 | 7259 |
| 11 | medium | medium | 3000 | 6329 |
| 19 | medium | medium | 3000 | 4061 |
| 21 | medium | medium | 3000 | 3151 |

## Notes

- Validation split is intentionally small and should be treated as a baseline smoke-test.
- Metrics are generated from the persisted model artifact, not from retraining.
