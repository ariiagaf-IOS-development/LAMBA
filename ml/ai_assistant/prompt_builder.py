#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
from typing import Any

try:
    from .prompt_templates import (
        DEFAULT_RESPONSE_CONSTRAINTS,
        SYSTEM_PROMPT_TEMPLATE,
        USER_MESSAGE_TEMPLATE,
        VEHICLE_CONTEXT_TEMPLATE,
    )
except ImportError:
    from prompt_templates import (
        DEFAULT_RESPONSE_CONSTRAINTS,
        SYSTEM_PROMPT_TEMPLATE,
        USER_MESSAGE_TEMPLATE,
        VEHICLE_CONTEXT_TEMPLATE,
    )


AI_ASSISTANT_DIR = Path(__file__).resolve().parent
DEFAULT_CONTEXT_PATH = AI_ASSISTANT_DIR / "example_context_payload.json"
DEFAULT_OUTPUT_PATH = AI_ASSISTANT_DIR / "example_prompt_payload.json"
SYSTEM_PROMPT_PATH = AI_ASSISTANT_DIR / "system_prompt.md"
SAFETY_RULES_PATH = AI_ASSISTANT_DIR / "safety_rules.md"


def _read_optional_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8").strip()


def _json_block(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True)


def _compact_event(event: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": event.get("id"),
        "type": event.get("type"),
        "title": event.get("title"),
        "description": event.get("description"),
        "mileage_km": event.get("mileage_km"),
        "cost": event.get("cost"),
        "event_date": event.get("event_date"),
        "metadata": event.get("metadata"),
        "assistant_hint": event.get("assistant_hint"),
    }


def _compact_part_health(part: dict[str, Any]) -> dict[str, Any]:
    return {
        "part_category": part.get("part_category"),
        "part_name": part.get("part_name"),
        "health_score": part.get("health_score"),
        "risk_level": part.get("risk_level"),
        "mileage_since_service_km": part.get("mileage_since_service_km"),
        "remaining_km": part.get("remaining_km"),
        "recommendation": part.get("recommendation"),
        "assistant_hint": part.get("assistant_hint"),
    }


def _compact_prediction(prediction: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": prediction.get("id"),
        "part_category": prediction.get("part_category"),
        "part_name": prediction.get("part_name"),
        "risk_level": prediction.get("risk_level"),
        "risk_score": prediction.get("risk_score"),
        "remaining_km": prediction.get("remaining_km"),
        "remaining_days": prediction.get("remaining_days"),
        "predicted_next_mileage": prediction.get("predicted_next_mileage"),
        "predicted_next_date": prediction.get("predicted_next_date"),
        "probability": prediction.get("probability"),
        "recommendation": prediction.get("recommendation"),
        "explanation": prediction.get("explanation"),
        "assistant_hint": prediction.get("assistant_hint"),
    }


def build_system_prompt() -> str:
    base_prompt = _read_optional_text(SYSTEM_PROMPT_PATH)
    safety_rules = _read_optional_text(SAFETY_RULES_PATH)

    sections = [SYSTEM_PROMPT_TEMPLATE.strip()]
    if base_prompt:
        sections.append(base_prompt)
    if safety_rules:
        sections.append("SAFETY RULES\n\n" + safety_rules)

    return "\n\n---\n\n".join(sections)


def build_vehicle_context(context: dict[str, Any], max_events: int = 8) -> str:
    timeline_events = context.get("timeline", {}).get("events", [])
    recent_events = timeline_events[-max_events:]
    parts = context.get("parts_health", {}).get("parts", [])
    predictions = context.get("predictions", {}).get("items", [])

    return VEHICLE_CONTEXT_TEMPLATE.format(
        schema_version=context.get("schema_version"),
        context_id=context.get("context_id"),
        generated_at=context.get("generated_at"),
        assistant=_json_block(context.get("assistant", {})),
        vehicle=_json_block(context.get("vehicle", {})),
        timeline_events=_json_block([_compact_event(event) for event in recent_events]),
        parts_health=_json_block([_compact_part_health(part) for part in parts]),
        predictions=_json_block([_compact_prediction(item) for item in predictions]),
        grounding=_json_block(context.get("grounding", {})),
    ).strip()


def build_user_prompt(
    user_message: str,
    context: dict[str, Any],
    intent_hint: str | None = None,
    response_constraints: list[str] | None = None,
) -> str:
    constraints = response_constraints or DEFAULT_RESPONSE_CONSTRAINTS
    assistant = context.get("assistant", {})
    mode = assistant.get("response_mode")

    enriched_constraints = [*constraints]
    if mode:
        enriched_constraints.append(f"Response mode from context: {mode}.")

    return USER_MESSAGE_TEMPLATE.format(
        intent_hint=intent_hint or "general_vehicle_question",
        user_message=user_message,
        response_constraints=_json_block(enriched_constraints),
    ).strip()


def build_prompt_payload(
    user_message: str,
    context: dict[str, Any],
    intent_hint: str | None = None,
) -> dict[str, Any]:
    return {
        "schema_version": "ai-assistant-prompt-v0.1",
        "context_id": context.get("context_id"),
        "model_provider": "llm",
        "messages": [
            {
                "role": "system",
                "content": build_system_prompt(),
            },
            {
                "role": "user",
                "content": build_vehicle_context(context),
            },
            {
                "role": "user",
                "content": build_user_prompt(user_message, context, intent_hint),
            },
        ],
        "metadata": {
            "vehicle_id": context.get("vehicle", {}).get("id"),
            "overall_risk_level": context.get("grounding", {}).get("overall_risk_level"),
            "intent_hint": intent_hint or "general_vehicle_question",
            "source_context_schema_version": context.get("schema_version"),
        },
    }


def load_context(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_prompt_payload(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Build an example LAMBA AI assistant prompt payload.")
    parser.add_argument("--context", default=DEFAULT_CONTEXT_PATH, type=Path)
    parser.add_argument("--output", default=DEFAULT_OUTPUT_PATH, type=Path)
    parser.add_argument("--message", default="What is the most important thing about the vehicle right now?")
    parser.add_argument("--intent-hint", default="vehicle_status_summary")
    args = parser.parse_args()

    context = load_context(args.context)
    payload = build_prompt_payload(args.message, context, args.intent_hint)
    write_prompt_payload(args.output, payload)
    print(f"output={args.output}")


if __name__ == "__main__":
    main()
