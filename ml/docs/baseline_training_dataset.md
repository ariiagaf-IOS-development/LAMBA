# Baseline Training Dataset

## Goal

Prepare the first model-ready training dataset from demo data and generate baseline features from vehicle profile, mileage, maintenance history, repair history, and refueling history.

Generated outputs live in `ml/training/baseline`.

## Source Data

| File | Role |
| --- | --- |
| `ml/demo_data/vehicles.csv` | Vehicle profile, mileage, fuel, body, and transmission fields. |
| `ml/demo_data/vehicle_events.csv` | Timeline events used for maintenance, repair, and refueling aggregates. |
| `ml/demo_data/parts.csv` | Tracked parts state used for part age features. |

## Target Variable

The first baseline target is `maintenance_needed`.

| Property | Value |
| --- | --- |
| Type | Binary integer, `0` or `1`. |
| Entity | One row per vehicle. |
| Positive class | `1` means the source maintenance baseline says maintenance is needed. |
| Source | Parsed from the derived `Recorded maintenance baseline` event description. |
| Example text | `Maintenance history: Good; service count: 9; maintenance needed: 1.` |

The raw label text is not included as a feature.

## Feature Groups

### Vehicle Profile

| Feature | Description |
| --- | --- |
| `vehicle_age_years` | Dataset reference year minus vehicle production year. |
| `brand` | Vehicle brand. |
| `model` | Vehicle model. |
| `body_class` | Body class from profile enrichment. |
| `fuel_type` | Vehicle fuel type. |
| `transmission` | Transmission description. |

### Mileage

| Feature | Description |
| --- | --- |
| `mileage_km` | Current odometer reading. |
| `mileage_bucket` | Odometer bucket: `low`, `medium`, `high`, or `very_high`. |

### Maintenance History

| Feature | Description |
| --- | --- |
| `maintenance_event_count` | Count of non-recall maintenance events. |
| `service_count_source` | Service count parsed from the maintenance baseline description. |
| `maintenance_history_quality` | Source maintenance history quality label. |
| `maintenance_history_score` | Ordinal score where poor=0, average=1, good=2. |
| `km_since_last_maintenance` | Current mileage minus latest maintenance event mileage. |

### Repair History

| Feature | Description |
| --- | --- |
| `repair_event_count` | Count of repair events. |
| `km_since_last_repair` | Current mileage minus latest repair event mileage. |
| `repair_cost_total` | Sum of repair event costs in demo data. |

### Refueling History

| Feature | Description |
| --- | --- |
| `refuel_event_count` | Count of refuel events. |
| `km_since_last_refuel` | Current mileage minus latest refuel event mileage. |
| `fuel_efficiency_km_per_liter` | Fuel efficiency parsed from derived refuel event text. |

### Parts State

| Feature | Description |
| --- | --- |
| `tracked_part_count` | Number of tracked parts for the vehicle. |
| `avg_part_age_km` | Average current mileage minus part installation mileage. |
| `avg_km_since_part_service` | Average current mileage minus last part service mileage. |

## Split

The builder creates a deterministic stratified train/validation split.

| Property | Value |
| --- | --- |
| Split files | `train.csv`, `validation.csv`. |
| Validation ratio | `0.2`. |
| Random state | `42`. |
| Stratification key | `maintenance_needed`. |

## Generation Command

```bash
python3 ml/training/build_baseline_training_data.py
```

The command writes:

```text
ml/training/baseline/baseline_training_dataset.csv
ml/training/baseline/train.csv
ml/training/baseline/validation.csv
ml/training/baseline/feature_schema.json
```

## Acceptance Checklist

- Training dataset is prepared in `ml/training/baseline/baseline_training_dataset.csv`.
- Features are generated from vehicle profile, mileage, maintenance history, repair history, refueling history, and parts state.
- Train/validation split is created in `ml/training/baseline/train.csv` and `ml/training/baseline/validation.csv`.
- Feature schema is documented in `ml/training/baseline/feature_schema.json`.
- Dataset is ready for the first baseline model training pass.
