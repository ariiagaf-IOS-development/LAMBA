# Digital Twin Aggregation

## Goal

Create the first Digital Twin representation by aggregating the existing vehicle profile, lifecycle timeline events, parts health state, and maintenance predictions into one backend-friendly response.

The first schema version is `digital-twin-v0.1`.

## Response Shape

```json
{
  "digital_twin_id": "dt-101-2026-04-24T10:30:00Z",
  "schema_version": "digital-twin-v0.1",
  "generated_at": "2026-04-24T10:30:00Z",
  "vehicle": {},
  "timeline": {
    "taxonomy_version": "timeline-taxonomy-v0.1",
    "events": []
  },
  "parts_health": {
    "model_version": "parts-health-v0.1",
    "parts": []
  },
  "predictions": {
    "model_version": "maintenance-v1.2.0",
    "source": "ml_service",
    "items": []
  },
  "summary": {}
}
```

Machine-readable schema: `ml/digital_twin/schema.json`.
Example response: `ml/digital_twin/example_digital_twin_payload.json`.

## Aggregated Sections

### Vehicle Profile

The `vehicle` section is copied from the backend vehicle domain model.

Required fields:

| Field | Source | Rule |
| --- | --- | --- |
| `id` | `vehicles.id` | Vehicle identifier requested by the client. |
| `brand` | `vehicles.brand` | Trimmed display brand. |
| `model` | `vehicles.model` | Trimmed display model. |
| `year` | `vehicles.year` | Vehicle production year. |
| `mileage_km` | `vehicles.mileage_km` | Current odometer baseline for parts health and predictions. |

Optional fields:

| Field | Source | Rule |
| --- | --- | --- |
| `user_id` | `vehicles.user_id` | Include when the caller is authorized to see ownership context. |
| `vin` | `vehicles.vin` | Include as `null` when missing in ML-facing payloads. |
| `created_at` | `vehicles.created_at` | ISO 8601 timestamp. |
| `updated_at` | `vehicles.updated_at` | ISO 8601 timestamp. |

### Timeline Events

The `timeline.events` section uses the shared event schema from `ml/docs/timeline_event_taxonomy.md`.

Aggregation rules:

| Rule | Description |
| --- | --- |
| Ownership | Include only events for the requested `vehicle_id` and authorized `user_id`. |
| Type normalization | Convert legacy `service` events to `maintenance`. |
| Sorting | Return events by `event_date` ascending, then `id` ascending. |
| Limit | Default to the latest 100 events unless the API caller requests a different page. |
| Metadata | Preserve `metadata` as a flexible object because each event type has different fields. |
| Nulls | Preserve unknown `description`, `mileage_km`, `cost`, `source`, and `source_id` as `null`. |

### Parts Health

The `parts_health.parts` section uses the output model from `ml/docs/parts_health_model.md`.

Aggregation rules:

| Rule | Description |
| --- | --- |
| Source parts | Start from all tracked parts returned by `PartRepository.ListByVehicleForUser`. |
| Category key | Use normalized `part_category` when present; otherwise use catalog code or normalized part name. |
| Mileage baseline | Use `vehicle.mileage_km` as `current_mileage_km`. |
| Service data | Prefer the latest matching maintenance or part replacement event over stale part metadata. |
| Repair data | Attach repair events where `metadata.part_category` matches the normalized part category. |
| Prediction data | Attach prediction outputs where `part_category`, `part_code`, or normalized `part_name` matches the part. |
| Missing data | Return the part with lower confidence instead of dropping it when service or prediction data is missing. |

### Predictions

The `predictions.items` section mirrors the backend prediction domain model and the ML prediction response.

Aggregation rules:

| Rule | Description |
| --- | --- |
| Freshness | Use latest saved predictions for the vehicle when available. |
| Recalculation | Generate predictions before building the twin when no saved prediction exists. |
| Source | Set `source` to `ml_service`, `rule_based`, or `mock` according to the prediction provider. |
| Ordering | Sort predictions by risk severity descending, then `risk_score` descending, then `part_name` ascending. |
| Version | Use the common prediction `model_version` when all items share one version. |
| Mixed versions | If prediction items have different versions, keep each item version in the item payload in the next schema revision. |

## Summary Rules

The `summary` section gives clients a compact state of the twin.

| Field | Rule |
| --- | --- |
| `overall_risk_level` | Highest severity across predictions, parts health, open warnings, and open recalls. |
| `highest_risk_parts` | Part categories with `high` risk from predictions or parts health. |
| `open_warnings_count` | Count timeline events where `type=warning` and `metadata.is_active=true`. |
| `open_recalls_count` | Count timeline events where `type=recall` and `metadata.status` is not `completed`, `closed`, or `resolved`. |
| `latest_event_date` | Max `event_date` from the included timeline events, or `null` when there are no events. |
| `next_recommended_actions` | Deduplicated high-priority recommendations from high-risk predictions, high-risk parts, open recalls, and active warnings. |

Risk severity order:

```text
high > medium > low
```

## Aggregation Flow

1. Validate that the requested vehicle belongs to the authenticated user.
2. Load vehicle profile.
3. Load timeline events with the timeline repository filter.
4. Normalize event types and sort timeline data.
5. Load tracked parts and part catalog metadata.
6. Load latest saved predictions, or recalculate predictions when none exist.
7. Calculate parts health using vehicle mileage, matching service events, matching repair events, and prediction outputs.
8. Build summary values from the aggregated sections.
9. Return the `digital-twin-v0.1` response.

## Error Handling

| Scenario | Expected behavior |
| --- | --- |
| Vehicle not found or not owned by user | Return the backend repository not-found error. |
| Empty timeline | Return `timeline.events: []` and `summary.latest_event_date: null`. |
| Empty tracked parts | Return `parts_health.parts: []`. |
| Empty predictions | Trigger prediction recalculation; if still empty, return `predictions.items: []`. |
| Prediction provider unavailable | Use existing prediction fallback behavior before building the twin. |
| Unknown event metadata | Preserve metadata without blocking the response. |

## Acceptance Checklist

- Digital Twin schema is documented in `ml/digital_twin/schema.json`.
- Vehicle profile is included under `vehicle`.
- Timeline data is included under `timeline.events`.
- Parts health is included under `parts_health.parts`.
- Prediction data is included under `predictions.items`.
- Example response is generated in `ml/digital_twin/example_digital_twin_payload.json`.
