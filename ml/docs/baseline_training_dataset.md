# Baseline Training Dataset

## Goal

Prepare the first model-ready training dataset from demo data and generate baseline features from vehicle profile, mileage, maintenance history, repair history, and refueling history.

Generated outputs live in `ml/training/baseline`.

The recommended first training dataset is now the expanded `vehicle_part` dataset. It increases the row count from 30 vehicle rows to 120 vehicle-part rows while keeping split isolation by `vehicle_id`.

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
| Entity | One row per vehicle in the compatibility dataset; one row per vehicle-part pair in the expanded dataset. |
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

## Expanded Vehicle-Part Features

The expanded dataset repeats vehicle-level features for each tracked part and adds part-specific features.

| Feature | Description |
| --- | --- |
| `part_id` | Part row identifier from `ml/demo_data/parts.csv`. |
| `part_name` | Tracked part display name. |
| `part_category` | Tracked part category. |
| `part_source` | Source system that produced the part row. |
| `part_age_km` | Current mileage minus part installation mileage, or `-1` when unknown. |
| `part_age_known` | `1` when part installation mileage is known, otherwise `0`. |
| `km_since_part_service` | Current mileage minus part last service mileage, or `-1` when unknown. |
| `km_since_part_service_known` | `1` when part last service mileage is known, otherwise `0`. |
| `is_core_maintenance_part` | `1` for engine oil, brake pads, or timing belt. |
| `matching_repair_event_count` | Number of repair events linked to the part by source id or text match. |
| `matching_repair_cost_total` | Total repair cost for events linked to this part. |

## Split

The builder creates two deterministic splits.

| Property | Value |
| --- | --- |
| Recommended split files | `expanded_train.csv`, `expanded_validation.csv`. |
| Compatibility split files | `train.csv`, `validation.csv`. |
| Validation ratio | `0.2`. |
| Random state | `42`. |
| Vehicle-level stratification key | `maintenance_needed`. |
| Expanded split rule | Inherit vehicle-level split by `vehicle_id` to prevent part-level leakage. |

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
ml/training/baseline/expanded_training_dataset.csv
ml/training/baseline/expanded_train.csv
ml/training/baseline/expanded_validation.csv
ml/training/baseline/expanded_feature_schema.json
```

## Acceptance Checklist

- Recommended training dataset is prepared in `ml/training/baseline/expanded_training_dataset.csv`.
- Vehicle-level compatibility dataset is prepared in `ml/training/baseline/baseline_training_dataset.csv`.
- Features are generated from vehicle profile, mileage, maintenance history, repair history, refueling history, and parts state.
- Expanded train/validation split is created in `ml/training/baseline/expanded_train.csv` and `ml/training/baseline/expanded_validation.csv`.
- Feature schema is documented in `ml/training/baseline/expanded_feature_schema.json`.
- Dataset is ready for the first baseline model training pass.
