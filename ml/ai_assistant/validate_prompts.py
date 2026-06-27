#!/usr/bin/env python3

import argparse
import json
import sys
from pathlib import Path


AI_ASSISTANT_DIR = Path(__file__).resolve().parent
ML_ROOT = AI_ASSISTANT_DIR.parent
PROJECT_ROOT = ML_ROOT.parent
DEFAULT_CONTEXT = AI_ASSISTANT_DIR / "example_context_payload.json"
DEFAULT_CASES = AI_ASSISTANT_DIR / "validation_cases.json"
DEFAULT_REPORT = ML_ROOT / "docs" / "ai_assistant_validation_report.md"

if str(AI_ASSISTANT_DIR) not in sys.path:
    sys.path.insert(0, str(AI_ASSISTANT_DIR))

from personality import build_personality_instructions  # noqa: E402
from personality import infer_personality_profile  # noqa: E402
from prompt_builder import build_prompt_payload  # noqa: E402


def _relative(path: Path) -> str:
    return str(path.resolve().relative_to(PROJECT_ROOT))


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _contains_required_safety(payload: dict) -> bool:
    content = "\n".join(message["content"] for message in payload["messages"])
    required_phrases = [
        "Do not invent vehicle data",
        "Do Not Give Definitive Diagnoses",
        "High-Risk Predictions Require Warnings",
        "Personality affects tone only",
        "The assistant speaks from the vehicle's first-person perspective",
    ]
    return all(phrase in content for phrase in required_phrases)


def build_report(context_path: Path, cases_path: Path) -> str:
    context = _load_json(context_path)
    cases_payload = _load_json(cases_path)
    _, personality = build_personality_instructions(context)

    lines = [
        "# AI Assistant Prompt Validation Report",
        "",
        "## Summary",
        "",
        f"- Context: `{_relative(context_path)}`",
        f"- Validation cases: `{_relative(cases_path)}`",
        f"- Selected personality profile: `{personality['selected_profile']}` ({personality['profile_name']})",
        f"- Vehicle voice: {personality['vehicle_voice']}",
        "",
        "## Personality Safety Rule",
        "",
        "Personality changes tone only. It must not change facts, risk level, probability, recommendations, warnings, or safety behavior.",
        "",
        "## Cases",
        "",
        "| Case | Intent | Prompt built | Safety/personality instructions present | Expected checks |",
        "| --- | --- | --- | --- | --- |",
    ]

    for case in cases_payload["cases"]:
        payload = build_prompt_payload(
            user_message=case["user_message"],
            context=context,
            intent_hint=case["intent_hint"],
        )
        safety_ok = _contains_required_safety(payload)
        checks = ", ".join(case["expected_checks"])
        lines.append(
            f"| `{case['id']}` | `{case['intent_hint']}` | yes | {'yes' if safety_ok else 'no'} | {checks} |"
        )

    lines.extend([
        "",
        "## Automatic Profile Selection Checks",
        "",
        "| Input hint | Expected profile | Actual profile |",
        "| --- | --- | --- |",
    ])

    auto_selection_cases = [
        ("pink color", {"metadata": {"color": "pink"}}, "pink_charm"),
        ("old vehicle", {"year": 2008, "metadata": {}}, "classic"),
        ("new vehicle", {"year": 2025, "metadata": {}}, "fresh"),
        ("sports car", {"metadata": {"vehicle_type": "sports_car"}}, "sporty"),
        ("family car", {"metadata": {"vehicle_type": "family"}}, "family"),
    ]
    for label, vehicle_override, expected_profile in auto_selection_cases:
        test_context = json.loads(json.dumps(context))
        vehicle = test_context.setdefault("vehicle", {})
        vehicle.pop("metadata", None)
        vehicle.update(vehicle_override)
        actual_profile = infer_personality_profile(test_context)
        lines.append(f"| {label} | `{expected_profile}` | `{actual_profile}` |")

    lines.extend([
        "",
        "## Common Weak Cases",
        "",
        "- The model may overplay the car persona if the user asks casual questions. Safety rules must keep the answer grounded.",
        "- Playful tone must be reduced for high-risk predictions, active warnings, recalls, and drivability questions.",
        "- Missing data questions must still say that the current context does not contain the requested fact.",
        "- Vehicle data modification requests must ask for confirmation before saving changes.",
        "",
        "## Backend/Frontend Notes",
        "",
        "- Backend can select a profile through `vehicle.metadata.personality_profile`.",
        "- If no supported profile is provided, the prompt layer falls back to a conservative inferred profile.",
        "- Frontend can show the selected profile name if a visible car voice setting is added later.",
        "",
    ])

    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate LAMBA AI assistant prompt construction.")
    parser.add_argument("--context", default=DEFAULT_CONTEXT, type=Path)
    parser.add_argument("--cases", default=DEFAULT_CASES, type=Path)
    parser.add_argument("--report", default=DEFAULT_REPORT, type=Path)
    args = parser.parse_args()

    report = build_report(args.context, args.cases)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(report, encoding="utf-8")
    print(f"report={args.report}")


if __name__ == "__main__":
    main()
