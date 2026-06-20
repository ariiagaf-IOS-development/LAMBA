# AI Assistant Context Payload

## Goal

Define the unified context payload used by the AI Assistant when answering questions about a vehicle. The payload is derived from the Digital Twin and keeps the same core aggregates: vehicle data, timeline data, parts health, and prediction results.

The first schema version is `ai-assistant-context-v0.1`.

## Payload Shape

```json
{
  "context_id": "ctx-101-2026-04-24T10:31:00Z",
  "schema_version": "ai-assistant-context-v0.1",
  "generated_at": "2026-04-24T10:31:00Z",
  "assistant": {},
  "digital_twin_ref": {},
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
  "grounding": {}
}
```

Machine-readable schema: `ml/ai_assistant/context_schema.json`.
Example payload: `ml/ai_assistant/example_context_payload.json`.

## Context Sections

### Assistant Metadata

The `assistant` section describes how the context should be used by the AI Assistant.

| Field | Rule |
| --- | --- |
| `locale` | Preferred response locale, such as `en-US` or `ru-RU`. |
| `audience` | One of `owner`, `technician`, or `support`. |
| `response_mode` | One of `concise`, `detailed`, or `diagnostic`. |
| `safety_instructions` | Optional guardrails for safety-sensitive vehicle advice. |

### Digital Twin Reference

The `digital_twin_ref` section links this context payload to the Digital Twin snapshot that produced it.

| Field | Rule |
| --- | --- |
| `digital_twin_id` | Copied from the source Digital Twin. |
| `schema_version` | Must be `digital-twin-v0.1`. |
| `generated_at` | Copied from the source Digital Twin. |

### Vehicle Data

The `vehicle` section is copied from the Digital Twin `vehicle` section.

Required fields:

| Field | Source |
| --- | --- |
| `id` | Digital Twin `vehicle.id`. |
| `brand` | Digital Twin `vehicle.brand`. |
| `model` | Digital Twin `vehicle.model`. |
| `year` | Digital Twin `vehicle.year`. |
| `mileage_km` | Digital Twin `vehicle.mileage_km`. |

Optional fields such as `user_id`, `vin`, `created_at`, and `updated_at` may be included when authorized.

### Timeline Data

The `timeline.events` section is derived from Digital Twin timeline events and adds `assistant_hint`.

| Field | Rule |
| --- | --- |
| `taxonomy_version` | Copied from Digital Twin `timeline.taxonomy_version`. |
| `events` | Filtered or full set of Digital Twin timeline events. |
| `assistant_hint` | Required short explanation of how the event should influence assistant answers. |

Recommended timeline filtering:

| Rule | Description |
| --- | --- |
| Include urgent events | Always include active warnings, open recalls, recent diagnostics, accidents, and high-risk prediction events. |
| Include maintenance evidence | Include maintenance and part replacement events that explain current parts health. |
| Keep order stable | Sort by `event_date` ascending, then `id` ascending. |
| Preserve metadata | Keep original event metadata for grounding and citations. |

### Parts Health

The `parts_health.parts` section is derived from Digital Twin parts health and adds `assistant_hint`.

| Field | Rule |
| --- | --- |
| `model_version` | Copied from Digital Twin `parts_health.model_version`. |
| `parts` | Include high-risk, medium-risk, recently serviced, or user-mentioned parts. |
| `assistant_hint` | Required explanation of how the part should be discussed. |

### Predictions

The `predictions.items` section is derived from Digital Twin prediction results and adds `assistant_hint`.

| Field | Rule |
| --- | --- |
| `model_version` | Copied from Digital Twin `predictions.model_version`. |
| `source` | Copied from Digital Twin `predictions.source`. |
| `items` | Include predictions relevant to current risks, upcoming service, or user query scope. |
| `assistant_hint` | Required guidance for explaining the prediction clearly. |

### Grounding

The `grounding` section gives the AI Assistant compact, citation-ready facts.

| Field | Rule |
| --- | --- |
| `overall_risk_level` | Copied from Digital Twin summary or recomputed from included context. |
| `active_alerts` | High-signal warnings, recalls, high-risk parts, and high-risk predictions. |
| `recommended_actions` | Deduplicated next actions from Digital Twin summary and included context. |
| `evidence` | Short factual statements with source references to vehicle, timeline, parts, or predictions. |

## Digital Twin Compatibility

The AI Assistant context is approved as compatible with `digital-twin-v0.1` when these rules hold:

| Compatibility rule | Expected behavior |
| --- | --- |
| Same aggregate names | Context keeps `vehicle`, `timeline`, `parts_health`, and `predictions`. |
| Same base field names | Fields copied from Digital Twin keep the same names and scalar types. |
| Additive assistant fields | Context may add `assistant`, `digital_twin_ref`, `grounding`, and `assistant_hint` fields. |
| No mutation of facts | Context must not alter factual values from Digital Twin sections. |
| Safe filtering | Context may omit low-signal timeline events, parts, or predictions, but must keep the full Digital Twin reference. |
| Source traceability | Every alert or evidence item should point to a source object by `source_type` and `source_id`. |

This means clients can build AI Assistant context from a Digital Twin snapshot without re-querying vehicle, event, parts, or prediction stores.

## Generation Flow

1. Build or load a `digital-twin-v0.1` payload.
2. Create `context_id` and `generated_at` for the assistant context snapshot.
3. Copy `vehicle`, `timeline`, `parts_health`, and `predictions` from the Digital Twin.
4. Filter low-signal context when needed for prompt size limits.
5. Add `assistant_hint` to included timeline events, parts, and predictions.
6. Build `grounding.active_alerts` from high-risk predictions, high-risk parts, active warnings, and open recalls.
7. Build `grounding.evidence` from the strongest source facts needed for assistant answers.
8. Return the `ai-assistant-context-v0.1` payload to the AI Assistant layer.

## Acceptance Checklist

- Context schema is documented in `ml/ai_assistant/context_schema.json`.
- Vehicle information is included under `vehicle`.
- Timeline information is included under `timeline.events`.
- Parts information is included under `parts_health.parts`.
- Prediction information is included under `predictions.items`.
- Example payload is generated in `ml/ai_assistant/example_context_payload.json`.
- Payload is approved for AI Assistant integration through the Digital Twin compatibility rules above.
