# Parts Health Model

## Goal

The Parts Health Model defines a deterministic component health score for Digital Twin and prediction services. It converts mileage, service history, repair history, and ML prediction outputs into a normalized `health_score` from `0` to `100`.

`100` means the component is healthy. `0` means the component is overdue, repeatedly repaired, or predicted as likely to fail.

## Output Schema

```json
{
  "model_version": "parts-health-v0.1",
  "part_category": "engine_oil",
  "part_name": "Engine oil",
  "health_score": 48,
  "risk_level": "medium",
  "current_mileage_km": 128500,
  "mileage_since_service_km": 8500,
  "remaining_km": 1500,
  "inputs": {
    "mileage": {
      "current_mileage_km": 128500,
      "installed_at_mileage_km": 100000,
      "last_service_mileage_km": 120000
    },
    "service_history": [],
    "repair_history": [],
    "prediction_outputs": []
  },
  "score_breakdown": {
    "mileage_score": 70,
    "service_score": 100,
    "repair_score": 100,
    "prediction_score": 28,
    "weights": {
      "mileage": 0.4,
      "service_history": 0.2,
      "repair_history": 0.15,
      "prediction_outputs": 0.25
    }
  },
  "recommendation": "Oil replacement will be required soon."
}
```

Vehicle-level responses wrap component outputs:

```json
{
  "vehicle_id": 101,
  "model_version": "parts-health-v0.1",
  "parts_health": []
}
```

## Risk Levels

| health_score | risk_level | Meaning |
| --- | --- | --- |
| 75-100 | low | Component is healthy or only lightly worn. |
| 40-74 | medium | Component is wearing out and should be monitored or serviced soon. |
| 0-39 | high | Component is overdue, close to failure, or predicted as high risk. |

The model intentionally reuses the existing backend-compatible risk enum: `low`, `medium`, `high`.

## Calculation Inputs

### Mileage

Mileage is the primary wear signal. The model calculates:

```text
mileage_since_service_km = current_mileage_km - last_service_or_install_mileage_km
remaining_km = service_interval_km - mileage_since_service_km
```

If `last_service_mileage_km` is missing, the model falls back to `installed_at_mileage_km`. If both are missing, the component is scored from vehicle mileage with a lower service confidence.

### Service History

Service events with type `service` or `maintenance` improve service confidence. The latest event mileage can override stale part metadata when it is more recent.

Service score:

| Condition | service_score |
| --- | --- |
| Known last service mileage exists | 100 |
| No service data exists | 60 |

### Repair History

Recent repairs reduce confidence because repeated repairs can indicate recurring failure or poor condition. The current rule counts repair events inside the component service interval.

```text
repair_score = 100 - repair_count * repair_penalty
```

The result is clamped to `0-100`.

### Prediction Outputs

Prediction outputs are converted into a health-oriented score:

| Prediction field | Conversion |
| --- | --- |
| `risk_score` | `prediction_score = 100 - risk_score` |
| `probability` | `prediction_score = 100 - probability * 100` |
| `risk_level=high` | `prediction_score = 25` |
| `risk_level=medium` | `prediction_score = 55` |
| no prediction | `prediction_score = 75` |

## Final Formula

```text
health_score =
  mileage_score * 0.40 +
  service_score * 0.20 +
  repair_score * 0.15 +
  prediction_score * 0.25
```

The final value is rounded to the nearest integer and clamped to `0-100`.

## Component Rules

Initial supported component categories are defined in `ml/parts_health/rules.py`:

| part_category | Service interval |
| --- | --- |
| `engine_oil` | 10,000 km |
| `brake_pads` | 40,000 km |
| `timing_belt` | 90,000 km |
| `battery` | 60,000 km |
| `tires` | 50,000 km |
| `air_filter` | 20,000 km |

Aliases such as `oil`, `brakes`, and `timing belt` are normalized to backend-friendly categories.

## Backend Review Notes

Backend should validate:

- `health_score` is an integer in range `0-100`.
- `risk_level` is one of `low`, `medium`, `high`.
- `part_category` uses normalized snake_case values.
- `parts_health` can be added to Digital Twin responses without changing the existing prediction response contract.

Example outputs are available in `ml/parts_health/examples.json`.
