# Timeline Event Taxonomy

## Goal

The timeline event taxonomy expands supported vehicle lifecycle events for Digital Twin and AI Assistant context. It defines the event `type` values, their meaning, and how each type maps to the shared timeline schema.

## Current State

Current demo data uses:

| Existing type | Status | Notes |
| --- | --- | --- |
| `trip` | supported | Mileage and usage baseline. |
| `refuel` | supported | Fuel or energy usage event. |
| `repair` | supported | Corrective work or complaint-derived event. |
| `service` | legacy alias | Kept for backward compatibility and normalized to `maintenance`. |

## Supported Event Types

| Event type | Description |
| --- | --- |
| `trip` | Driving activity or mileage baseline event used to update vehicle usage context. |
| `refuel` | Fueling or charging event with optional consumption and cost data. |
| `repair` | Completed corrective work after component failure, complaint, or malfunction. |
| `inspection` | Manual or automated vehicle check that records observed condition without necessarily replacing parts. |
| `accident` | Collision, crash, impact, or safety incident that may affect future vehicle condition. |
| `recall` | Manufacturer or regulator recall notice, campaign, remedy, or recall completion event. |
| `warning` | Dashboard light, sensor alert, owner warning, or system notification that indicates possible risk. |
| `maintenance` | Planned preventive service such as oil change, brake service, tire rotation, or scheduled replacement. |
| `prediction` | ML-generated forecast about component risk, remaining distance, or recommended next action. |
| `diagnostic` | Diagnostic scan, trouble code reading, test result, or technician finding. |

## Timeline Schema Mapping

All event types use the same base timeline schema:

```json
{
  "id": 1001,
  "vehicle_id": 101,
  "type": "maintenance",
  "title": "Engine oil replacement",
  "description": "Scheduled oil and oil filter replacement completed.",
  "mileage_km": 128500,
  "cost": 85.0,
  "event_date": "2026-04-23T11:00:00Z",
  "source": "service_center",
  "source_id": "work-order-9912",
  "metadata": {}
}
```

Required fields:

| Field | Type | Notes |
| --- | --- | --- |
| `id` | integer | Unique timeline event id. |
| `vehicle_id` | integer | Vehicle foreign key. |
| `type` | enum string | Must be one supported event type. |
| `title` | string | Short human-readable event name. |
| `event_date` | datetime string | ISO 8601 timestamp. |

Optional fields:

| Field | Type | Notes |
| --- | --- | --- |
| `description` | string or null | Longer event details for UI and AI context. |
| `mileage_km` | integer or null | Odometer reading when known. |
| `cost` | number or null | Event cost when known. |
| `source` | string or null | Data source such as owner report, service center, ML service, or recall feed. |
| `source_id` | string, integer, or null | External id from the source system. |
| `metadata` | object or null | Type-specific structured details. |

## Type-Specific Metadata

| Event type | Recommended metadata |
| --- | --- |
| `trip` | `distance_km`, `duration_minutes`, `route_type` |
| `refuel` | `fuel_type`, `liters`, `price_per_liter`, `station_name` |
| `repair` | `part_category`, `part_name`, `repair_shop`, `warranty_covered` |
| `inspection` | `inspection_result`, `inspector`, `checked_components`, `next_check_due` |
| `accident` | `severity`, `damage_area`, `airbags_deployed`, `insurance_claim_id` |
| `recall` | `recall_id`, `status`, `component`, `remedy`, `manufacturer` |
| `warning` | `warning_code`, `severity`, `system`, `is_active` |
| `maintenance` | `service_name`, `part_category`, `parts_replaced`, `service_provider` |
| `prediction` | `model_version`, `part_category`, `risk_level`, `probability`, `remaining_km` |
| `diagnostic` | `dtc_codes`, `system`, `tool_name`, `result` |

## Normalization Rules

`service` is a legacy type from existing demo data. New producers should send `maintenance`.

Normalization:

```text
service -> maintenance
```

Consumers should accept `service` while historical data is still present, but UI and AI context should display it as maintenance.

## AI Assistant Context Use

The AI Assistant should use event types as context hints:

| Event type | Assistant behavior |
| --- | --- |
| `inspection` | Treat as observed condition and cite findings when explaining recommendations. |
| `accident` | Consider as a possible cause of later repairs, warnings, or safety issues. |
| `recall` | Prioritize open safety campaigns and explain remedy status. |
| `warning` | Surface active warnings as urgent context. |
| `maintenance` | Use as evidence that preventive service was completed. |
| `prediction` | Explain model-generated risk and remaining distance. |
| `diagnostic` | Ground answers in DTC codes, scan results, and test findings. |

## Backend Review Notes

Backend should validate:

- `type` is one of the supported event types from `ml/timeline/event_types.py`.
- `service` remains accepted only as a legacy alias.
- `event_date` is an ISO 8601 datetime string.
- `metadata` remains flexible because each event type has different structured details.

Machine-readable taxonomy is available in `ml/timeline/event_taxonomy.json`.
Examples are available in `ml/timeline/example_timeline_events.json`.
