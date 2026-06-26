# AI Assistant Prompt Format

This document describes the prompt payload format for the LAMBA AI assistant.

Related files:

- `ml/ai_assistant/context_schema.json`
- `ml/ai_assistant/example_context_payload.json`
- `ml/ai_assistant/prompt_templates.py`
- `ml/ai_assistant/prompt_builder.py`
- `ml/ai_assistant/example_prompt_payload.json`

## Goal

The prompt format standardizes how LAMBA passes vehicle context and user messages to DeepSeek or another LLM provider.

The prompt must:

- include the vehicle profile;
- include recent timeline events;
- include parts health;
- include prediction results;
- include grounding alerts, actions, and evidence;
- wrap the user message in a consistent format;
- include intent hints and response constraints;
- stay aligned with `context_schema.json`.

## Payload Shape

The generated prompt payload has this structure:

```json
{
  "schema_version": "ai-assistant-prompt-v0.1",
  "context_id": "ctx-101-2026-04-24T10:31:00Z",
  "model_provider": "llm",
  "messages": [],
  "metadata": {}
}
```

## Messages

The `messages` array is ordered intentionally.

| Role | Content |
| --- | --- |
| `system` | Base system prompt, assistant persona, and safety rules. |
| `user` | Serialized vehicle context from `context_schema.json`. |
| `user` | User message wrapper with intent hint and response constraints. |

This shape is close to common chat-completion APIs and can be adapted by the backend provider layer.

## System Message

Built by:

```python
build_system_prompt()
```

Sources:

- `ml/ai_assistant/system_prompt.md`
- `ml/ai_assistant/safety_rules.md`
- `ml/ai_assistant/prompt_templates.py`

The system message defines:

- assistant persona;
- grounding behavior;
- safety rules;
- high-risk response requirements;
- confirmation rules before vehicle data modification.

## Vehicle Context Message

Built by:

```python
build_vehicle_context(context)
```

Included context sections:

- `schema_version`
- `context_id`
- `generated_at`
- `assistant`
- `vehicle`
- `timeline.events`
- `parts_health.parts`
- `predictions.items`
- `grounding`

The builder compacts timeline, part health, and prediction items to include the fields most useful to the assistant while preserving source IDs and assistant hints.

## User Message Wrapper

Built by:

```python
build_user_prompt(user_message, context, intent_hint)
```

The wrapper includes:

- `intent_hint`;
- raw user message;
- response constraints.

Default response constraints:

- use only facts from the context;
- separate confirmed facts from ML estimates;
- do not provide definitive diagnoses;
- recommend professional inspection or service for high-risk issues;
- ask for confirmation before creating, editing, or deleting vehicle data.

## Intent Hints

Suggested intent hints for the MVP:

| Intent | Use case |
| --- | --- |
| `vehicle_status_summary` | User asks what is currently important about the vehicle. |
| `maintenance_timing` | User asks when to service a part. |
| `risk_explanation` | User asks why a prediction or part has a risk level. |
| `drivability_safety` | User asks whether it is safe to drive. |
| `diagnostic_explanation` | User asks about warnings or OBD codes. |
| `vehicle_data_modification` | User asks to add, edit, close, or delete vehicle data. |
| `missing_context_question` | User asks for data that may not exist in context. |

Intent hints should guide response structure, not change facts or safety requirements.

## Backend Integration Notes

Backend should provide a context payload aligned with:

```text
ml/ai_assistant/context_schema.json
```

Then it can call:

```python
from ai_assistant.prompt_builder import build_prompt_payload

payload = build_prompt_payload(
    user_message=user_message,
    context=context,
    intent_hint="vehicle_status_summary",
)
```

The returned `payload["messages"]` can be passed to the selected LLM provider after provider-specific conversion.

## Example

Generate the example payload:

```bash
python3 ml/ai_assistant/prompt_builder.py
```

Output:

```text
ml/ai_assistant/example_prompt_payload.json
```

## Acceptance Checklist for LAMBA#31

- Prompt format matches `context_schema.json`.
- Vehicle profile is injected.
- Recent events are injected.
- Parts health is injected.
- Prediction results are injected.
- User messages are standardized.
- Intent hints are supported.
- Response constraints are included.
- Backend can review and adapt the generated `messages` payload.
