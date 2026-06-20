# Backend and ML Alignment Gaps

## Goal

This document captures current integration gaps between Backend and ML contracts. It is intended for Backend, ML, and AI review before timeline taxonomy and parts health outputs are treated as fully approved.

## Summary

The ML-side taxonomy and parts health model are documented, but Backend is not fully synchronized yet. The biggest risk is that ML now documents event types that Backend currently rejects at validation or database constraint level.

## Timeline Event Type Gaps

### Backend does not accept all ML timeline event types

ML timeline taxonomy supports:

```text
trip, refuel, repair, inspection, accident, recall, warning, maintenance, prediction, diagnostic
```

Backend currently accepts:

```text
maintenance, repair, fuel, diagnostic, part_replacement, note
```

Impact:

- `inspection`, `accident`, `recall`, `warning`, and `prediction` events can be documented in ML but rejected by Backend.
- AI Assistant context may be incomplete because these richer timeline events cannot be stored through the Backend API.

Relevant files:

- `ml/timeline/event_types.py`
- `ml/timeline/event_taxonomy.json`
- `backend/internal/domain/vehicle_event.go`

### Database constraint is also not aligned

Backend database migration currently constrains `vehicle_events.type` to:

```text
maintenance, repair, fuel, diagnostic, part_replacement, note
```

Impact:

- Updating only Go enum validation is not enough.
- New timeline event types also need a database migration that updates the `vehicle_events_type_allowed` check constraint.

Relevant file:

- `backend/internal/infrastructure/db/migrations/002_extend_vehicle_events.sql`

### `fuel` vs `refuel`

ML and demo data use:

```text
refuel
```

Backend uses:

```text
fuel
```

Recommended resolution:

- Use `refuel` as the canonical type because it is more specific and already exists in ML demo data.
- Keep `fuel` as a legacy alias if existing Backend/mobile clients already use it.

### `service` vs `maintenance`

ML taxonomy treats:

```text
service -> maintenance
```

as a legacy alias.

Impact:

- Historical demo data and older docs may still contain `service`.
- Backend should either accept `service` as a legacy alias or migrate old events to `maintenance`.

Recommended resolution:

- Canonical type: `maintenance`.
- Legacy alias: `service`.

## Timeline Schema Gaps

### `source` and `source_id` are documented in ML but not modeled directly in Backend

ML timeline examples include:

```json
{
  "source": "service_center",
  "source_id": "inspection-7781"
}
```

Backend `VehicleEvent` currently has flexible `metadata`, but no explicit `source` or `source_id` fields.

Impact:

- Source attribution may be lost or inconsistently stored.
- AI Assistant may not know whether an event came from an owner report, service center, recall feed, ML service, or diagnostic tool.

Recommended resolution options:

- Add `source` and `source_id` columns to Backend `vehicle_events`.
- Or define that `source` and `source_id` must live inside `metadata`.

The first option is better for filtering, auditability, and UI display.

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

## Recommended Backend Follow-up

Create a Backend-focused follow-up task:

```text
Backend: Align timeline event taxonomy and ML contracts
```

Suggested implementation scope:

- Update Backend `EventType` enum.
- Add aliases for `service -> maintenance` and optionally `fuel -> refuel`.
- Add a new DB migration for the `vehicle_events_type_allowed` constraint.
- Update Swagger docs.
- Add tests for all canonical timeline event types.
- Decide where `source` and `source_id` should live.
- Add Backend mapper from `VehiclePart` to ML part schema.
- Decide how `parts_health` is exposed to Digital Twin.

## Current Risk

Until these follow-ups are complete, the ML taxonomy is documented, but Backend may reject or fail to persist some documented timeline events. Parts Health Model is also available in ML but not yet connected to Backend or Digital Twin responses.
