# Backend and ML Alignment Gaps

## Goal

This document captures current integration gaps between Backend and ML contracts. It is intended for Backend, ML, and AI review before timeline taxonomy and parts health outputs are treated as fully approved.

## Summary

The timeline event type mismatch has been resolved in Backend: current Backend code accepts the ML timeline event types and also supports Backend-specific `part_replacement` and `note` types. Remaining gaps are now mostly about documentation, metadata placement, and future parts health integration.

## Timeline Event Type Gaps

### Backend and ML event types are now aligned

Shared canonical timeline types:

```text
trip, refuel, repair, inspection, accident, recall, warning, maintenance, prediction, diagnostic, part_replacement, note
```

Resolved:

- Backend domain enum includes these types.
- Backend database migration updates legacy `fuel -> refuel` and `service -> maintenance`.
- ML taxonomy now documents `part_replacement` and `note`.

Relevant files:

- `ml/timeline/event_types.py`
- `ml/timeline/event_taxonomy.json`
- `backend/internal/domain/vehicle_event.go`
- `backend/internal/infrastructure/db/migrations/002_extend_vehicle_events.sql`

### `fuel` vs `refuel`

Canonical value is now `refuel`. Backend migration converts legacy `fuel` rows to `refuel`.

### `service` vs `maintenance`

ML taxonomy treats:

```text
service -> maintenance
```

as a legacy alias.

Backend migration converts legacy `service` rows to `maintenance`.

## Timeline Schema Gaps

### `source` and `source_id` live in `metadata`

ML timeline examples store source attribution inside `metadata`:

```json
{
  "metadata": {
    "source": "service_center",
    "source_id": "inspection-7781"
  }
}
```

Backend `VehicleEvent` has flexible `metadata`, but no explicit `source` or `source_id` fields. ML examples and taxonomy now follow the Backend-compatible approach and keep these values inside `metadata`.

Recommended resolution options:

- Current compatible approach: keep `source` and `source_id` inside `metadata`.
- Future enhancement: add first-class `source` and `source_id` columns if filtering or audit requirements grow.

## Parts Health Integration Gaps

### Parts Health Model is documented but not integrated into Backend responses

ML now has:

- `ml/parts_health/health_model.py`
- `ml/parts_health/rules.py`
- `ml/parts_health/examples.json`
- `ml/docs/parts_health_model.md`

But Backend does not currently call this calculation directly or expose a dedicated `parts_health` response.

Impact:

- Digital Twin cannot consume `health_score` unless Backend adds a mapping or endpoint.
- Parts health remains a documented ML module rather than an integrated product feature.

Recommended resolution:

- Add a Backend integration point for parts health.
- Decide whether `health_score` is stored in DB, computed on demand, or returned by an ML service endpoint.
- Add `parts_health` to the Digital Twin response once the Backend contract is approved.

### Backend part schema differs from ML part schema

ML prediction schema expects:

```text
part_category
part_name
installed_at_mileage_km
last_service_mileage_km
last_service_date
```

Backend part domain uses:

```text
catalog_code
name
category
installed_at_mileage_km
last_service_mileage_km
last_service_date
```

Impact:

- Backend cannot blindly forward `VehiclePart` JSON as an ML request.
- A mapper is required between Backend domain fields and ML request fields.

Recommended mapping:

| Backend field | ML field |
| --- | --- |
| `category` or `catalog_code` | `part_category` |
| `name` | `part_name` |
| `installed_at_mileage_km` | `installed_at_mileage_km` |
| `last_service_mileage_km` | `last_service_mileage_km` |
| `last_service_date` | `last_service_date` |

## Prediction Contract Notes

Prediction risk levels are aligned:

```text
low, medium, high
```

Both Backend and ML use this enum.

Fields that should remain aligned:

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
- `model_version`

## Recommended Follow-up

Create an integration-focused follow-up task:

```text
Backend/ML: Integrate parts health and prediction contract mapping
```

Suggested implementation scope:

- Add Backend mapper from `VehiclePart` to ML part schema.
- Decide how `parts_health` is exposed to Digital Twin.
- Decide whether parts health is computed on demand, stored, or returned by a future ML endpoint.
- Keep timeline examples and Backend API docs synchronized when event metadata conventions change.

## Current Risk

Timeline event types are now aligned between ML docs and Backend. Remaining risk is mainly that Parts Health Model is available in ML but not yet connected to Backend or Digital Twin responses.
