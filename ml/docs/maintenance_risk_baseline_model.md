# Maintenance Risk Baseline Model

## Goal

Train the first maintenance risk prediction baseline models and export a model artifact that can produce:

- `risk_level`: `low`, `medium`, or `high`
- `risk_score`: numeric risk score mapped from the predicted risk level
- `remaining_km`: estimated distance until recommended maintenance

## Training Data

The model uses the prepared baseline dataset in:

```text
ml/training/baseline/train.csv
ml/training/baseline/validation.csv
ml/training/baseline/feature_schema.json
```

The original binary source target is `maintenance_needed`. For this baseline training pass, the script derives:

| Target | Description |
| --- | --- |
| `risk_level` | Low/medium/high maintenance risk derived from `maintenance_needed`, mileage, service history, and part service age. |
| `remaining_km` | Estimated kilometers until recommended maintenance based on service age and risk level. |

## Trained Baselines

| Baseline | Risk model | Remaining km model |
| --- | --- | --- |
| `logistic_regression` | Logistic Regression | Decision Tree Regressor |
| `random_forest` | Random Forest Classifier | Random Forest Regressor |

The selected model is chosen by:

```text
risk_macro_f1 - remaining_km_mae / 12000
```

This keeps risk classification quality primary while penalizing poor remaining-kilometer estimates.

## Generated Files

Training command:

```bash
python3 ml/training/train_maintenance_baselines.py
```

Generated outputs:

| File | Purpose |
| --- | --- |
| `ml/training/artifacts/maintenance_risk_model.joblib` | Exported best model artifact. |
| `ml/training/artifacts/model_comparison.json` | Metrics for Logistic Regression and Random Forest baselines. |
| `ml/training/artifacts/sample_inference.json` | Example inference output from the selected model. |

Inference command:

```bash
python3 ml/training/inference_maintenance_model.py
```

## Current Result

Current selected model:

```text
random_forest
```

The dataset is intentionally small, so validation metrics should be treated as baseline smoke-test metrics rather than production-quality performance estimates.
