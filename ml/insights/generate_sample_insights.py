#!/usr/bin/env python3

import argparse
import csv
import json
import sys
from collections import defaultdict
from datetime import UTC, datetime
from pathlib import Path


INSIGHTS_DIR = Path(__file__).resolve().parent
ML_ROOT = INSIGHTS_DIR.parent
PROJECT_ROOT = ML_ROOT.parent

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from ml.parts_health.health_model import calculate_component_health  # noqa: E402
from ml.parts_health.rules import normalize_part_category  # noqa: E402


DEFAULT_DEMO_DIR = ML_ROOT / "demo_data"
DEFAULT_OUTPUT = INSIGHTS_DIR / "sample_vehicle_insights.json"
DEFAULT_REPORT = ML_ROOT / "docs" / "sample_vehicle_insights_validation_report.md"

SCHEMA_VERSION = "sample-vehicle-insights-v0.1"
MODEL_VERSION = "sample-insights-rules-v0.1"
REQUIRED_CATEGORIES = {"maintenance", "cost", "risk_prediction"}
ALLOWED_SOURCE_FILES = {
    "ml/demo_data/vehicles.csv",
    "ml/demo_data/vehicle_events.csv",
    "ml/demo_data/parts.csv",
}
TECHNICAL_JARGON = {
    "actuator",
    "capillary",
    "dtc",
    "ecu",
    "hecu",
    "p0300",
    "p0301",
    "p0303",
    "p1285",
}


def _relative(path: Path) -> str:
    return str(path.resolve().relative_to(PROJECT_ROOT))


def _read_csv(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as handle:
        return [dict(row) for row in csv.DictReader(handle)]


def _optional_int(value):
    if value in (None, ""):
        return None
    return int(float(value))


def _optional_float(value):
    if value in (None, ""):
        return None
    return float(value)


def _clean_vehicle(row: dict) -> dict:
    return {
        "id": _optional_int(row["id"]),
        "brand": row["brand"],
        "model": row["model"],
        "year": _optional_int(row["year"]),
        "vin": row.get("vin") or None,
        "mileage_km": _optional_int(row["mileage_km"]),
        "body_class": row.get("body_class") or None,
        "engine": row.get("engine") or None,
        "fuel_type": row.get("fuel_type") or None,
        "transmission": row.get("transmission") or None,
        "source": row.get("source") or None,
    }


def _clean_event(row: dict) -> dict:
    return {
        "id": _optional_int(row["id"]),
        "vehicle_id": _optional_int(row["vehicle_id"]),
        "type": row["type"],
        "title": row["title"],
        "description": row.get("description") or "",
        "mileage_km": _optional_int(row.get("mileage_km")),
        "cost": _optional_float(row.get("cost")),
        "event_date": row.get("event_date") or None,
        "source": row.get("source") or None,
        "source_id": row.get("source_id") or None,
    }


def _clean_part(row: dict) -> dict:
    return {
        "id": _optional_int(row["id"]),
        "vehicle_id": _optional_int(row["vehicle_id"]),
        "name": row["name"],
        "category": row["category"],
        "installed_at_mileage_km": _optional_int(row.get("installed_at_mileage_km")),
        "last_service_mileage_km": _optional_int(row.get("last_service_mileage_km")),
        "source": row.get("source") or None,
        "source_id": row.get("source_id") or None,
    }


def _load_demo_data(demo_dir: Path) -> tuple[list[dict], dict[int, list[dict]], dict[int, list[dict]]]:
    vehicles = [_clean_vehicle(row) for row in _read_csv(demo_dir / "vehicles.csv")]
    events_by_vehicle = defaultdict(list)
    parts_by_vehicle = defaultdict(list)

    for event in (_clean_event(row) for row in _read_csv(demo_dir / "vehicle_events.csv")):
        events_by_vehicle[event["vehicle_id"]].append(event)

    for part in (_clean_part(row) for row in _read_csv(demo_dir / "parts.csv")):
        parts_by_vehicle[part["vehicle_id"]].append(part)

    return vehicles, dict(events_by_vehicle), dict(parts_by_vehicle)


def _part_category(part: dict) -> str | None:
    name = part["name"].strip().lower()
    try:
        return normalize_part_category(name)
    except ValueError:
        return None


def _supported_parts(parts: list[dict]) -> list[dict]:
    supported = []
    for part in parts:
        category = _part_category(part)
        if not category:
            continue
        supported.append({**part, "part_category": category})
    return supported


def _event_sort_key(event: dict) -> tuple[str, int]:
    return (event.get("event_date") or "", event.get("id") or 0)


def _latest_event(events: list[dict], event_type: str) -> dict | None:
    matching = [event for event in events if str(event.get("type")).lower() == event_type]
    if not matching:
        return None
    return sorted(matching, key=_event_sort_key)[-1]


def _is_recall_event(event: dict) -> bool:
    title = str(event.get("title") or "").lower()
    source = str(event.get("source") or "").lower()
    return title.startswith("recall:") or "recalls" in source


def _service_events(events: list[dict]) -> list[dict]:
    return [
        event
        for event in events
        if str(event.get("type")).lower() in {"service", "maintenance"} and not _is_recall_event(event)
    ]


def _repair_events(events: list[dict]) -> list[dict]:
    return [event for event in events if str(event.get("type")).lower() == "repair"]


def _recall_events(events: list[dict]) -> list[dict]:
    return [event for event in events if _is_recall_event(event)]


def _build_parts_health(vehicle: dict, events: list[dict], parts: list[dict]) -> list[dict]:
    service_history = _service_events(events)
    repair_history = _repair_events(events)
    health_items = []

    for part in _supported_parts(parts):
        health = calculate_component_health(
            part_category=part["part_category"],
            current_mileage_km=vehicle["mileage_km"],
            service_history=service_history,
            repair_history=repair_history,
            prediction_outputs=[],
            installed_at_mileage_km=part.get("installed_at_mileage_km"),
            last_service_mileage_km=part.get("last_service_mileage_km"),
        )
        health_items.append(
            {
                "model_version": health["model_version"],
                "part_id": part["id"],
                "part_category": health["part_category"],
                "part_name": health["part_name"],
                "health_score": health["health_score"],
                "risk_level": health["risk_level"],
                "current_mileage_km": health["current_mileage_km"],
                "mileage_since_service_km": health["mileage_since_service_km"],
                "remaining_km": health["remaining_km"],
                "recommendation": health["recommendation"],
                "score_breakdown": health["score_breakdown"],
            }
        )

    return health_items


def _build_predictions(vehicle: dict, health_items: list[dict]) -> list[dict]:
    predictions = []
    for index, health in enumerate(health_items, start=1):
        risk_score = max(0, min(100, 100 - int(health["health_score"])))
        remaining_km = health.get("remaining_km")
        predictions.append(
            {
                "id": f"{vehicle['id']}-pred-{index}",
                "vehicle_id": vehicle["id"],
                "part_category": health["part_category"],
                "part_name": health["part_name"],
                "risk_level": health["risk_level"],
                "risk_score": risk_score,
                "remaining_km": remaining_km,
                "probability": round(risk_score / 100, 2),
                "recommendation": health["recommendation"],
                "model_version": MODEL_VERSION,
            }
        )
    return predictions


def _risk_rank(value: str) -> int:
    return {"high": 3, "medium": 2, "low": 1}.get(value, 0)


def _severity_from_risk(risk_level: str) -> str:
    return risk_level if risk_level in {"low", "medium", "high"} else "medium"


def _remaining_text(remaining_km: int | None) -> str:
    if remaining_km is None:
        return "the remaining distance is not available"
    if remaining_km < 0:
        return f"it is about {abs(remaining_km):,} km overdue"
    if remaining_km == 0:
        return "it is due now"
    return f"about {remaining_km:,} km remain"


def _money(value: float) -> str:
    return f"${value:,.2f}"


def _source_files(*names: str) -> list[str]:
    return sorted(names)


def _maintenance_insight(vehicle: dict, health_items: list[dict]) -> dict:
    focus = sorted(
        health_items,
        key=lambda item: (_risk_rank(item["risk_level"]), -(item.get("remaining_km") or 0)),
        reverse=True,
    )[0]
    remaining = _remaining_text(focus.get("remaining_km"))

    return {
        "id": f"{vehicle['id']}-maintenance",
        "category": "maintenance",
        "severity": _severity_from_risk(focus["risk_level"]),
        "title": f"Maintenance focus: {focus['part_name']}",
        "message": (
            f"{focus['part_name']} is the main maintenance item for this sample vehicle: "
            f"{remaining}. The recommendation is: {focus['recommendation']}"
        ),
        "evidence": [
            {
                "ref": f"vehicle:{vehicle['id']}",
                "statement": f"Current mileage is {vehicle['mileage_km']:,} km.",
            },
            {
                "ref": f"part:{focus['part_id']}",
                "statement": (
                    f"{focus['part_name']} has {focus['mileage_since_service_km']:,} km "
                    "since the last recorded service."
                ),
            },
        ],
        "source_files": _source_files("ml/demo_data/vehicles.csv", "ml/demo_data/parts.csv"),
    }


def _cost_insight(vehicle: dict, events: list[dict]) -> dict:
    cost_events = [
        event
        for event in events
        if str(event.get("type")).lower() in {"service", "maintenance", "repair", "refuel"}
    ]
    known_cost_events = [event for event in cost_events if event.get("cost") is not None]
    paid_events = [event for event in known_cost_events if event.get("cost", 0) > 0]
    total_cost = sum(event["cost"] for event in paid_events)
    latest_paid = sorted(paid_events, key=_event_sort_key)[-1] if paid_events else None

    if paid_events:
        message = (
            f"The provided events show {_money(total_cost)} in recorded costs across "
            f"{len(paid_events)} paid entries. The latest paid entry is "
            f"'{latest_paid['title']}' at {_money(latest_paid['cost'])}."
        )
        severity = "medium" if total_cost >= 1000 else "low"
        evidence = [
            {
                "ref": f"event:{latest_paid['id']}",
                "statement": f"Latest paid event cost is {_money(latest_paid['cost'])}.",
            }
        ]
    else:
        message = (
            "The sample data does not include any non-zero repair, service, or refuel costs "
            f"for this vehicle. Cost trend should not be estimated from this sample alone."
        )
        severity = "low"
        evidence = [
            {
                "ref": f"vehicle:{vehicle['id']}",
                "statement": f"{len(known_cost_events)} event cost fields are present, all recorded as zero.",
            }
        ]

    return {
        "id": f"{vehicle['id']}-cost",
        "category": "cost",
        "severity": severity,
        "title": "Cost data is limited",
        "message": message,
        "evidence": evidence,
        "source_files": _source_files("ml/demo_data/vehicle_events.csv"),
    }


def _risk_prediction_insight(vehicle: dict, events: list[dict], predictions: list[dict]) -> dict:
    highest_prediction = sorted(
        predictions,
        key=lambda item: (_risk_rank(item["risk_level"]), item["risk_score"]),
        reverse=True,
    )[0]
    latest_repair = _latest_event(_repair_events(events), "repair")
    recall_count = len(_recall_events(events))

    context_sentence = ""
    evidence = [
        {
            "ref": f"prediction:{highest_prediction['id']}",
            "statement": (
                f"{highest_prediction['part_name']} is {highest_prediction['risk_level']} risk "
                f"with score {highest_prediction['risk_score']}/100."
            ),
        }
    ]
    if latest_repair:
        context_sentence = f" The latest repair-related event is '{latest_repair['title']}'."
        evidence.append(
            {
                "ref": f"event:{latest_repair['id']}",
                "statement": f"Latest repair-related event date is {latest_repair['event_date']}.",
            }
        )
    elif recall_count:
        context_sentence = f" The sample also includes {recall_count} recall event(s)."

    return {
        "id": f"{vehicle['id']}-risk-prediction",
        "category": "risk_prediction",
        "severity": _severity_from_risk(highest_prediction["risk_level"]),
        "title": f"Risk signal: {highest_prediction['part_name']}",
        "message": (
            f"The rule-based prediction marks {highest_prediction['part_name']} as "
            f"{highest_prediction['risk_level']} risk. This is an estimate from the provided "
            f"mileage, service, and part data, not a final diagnosis.{context_sentence}"
        ),
        "evidence": evidence,
        "source_files": _source_files(
            "ml/demo_data/vehicles.csv",
            "ml/demo_data/vehicle_events.csv",
            "ml/demo_data/parts.csv",
        ),
    }


def _generate_vehicle_insights(vehicle: dict, events: list[dict], parts: list[dict]) -> dict:
    health_items = _build_parts_health(vehicle, events, parts)
    if not health_items:
        raise ValueError(f"Vehicle {vehicle['id']} has no supported parts for insights")

    predictions = _build_predictions(vehicle, health_items)
    insights = [
        _maintenance_insight(vehicle, health_items),
        _cost_insight(vehicle, events),
        _risk_prediction_insight(vehicle, events, predictions),
    ]

    return {
        "vehicle_id": vehicle["id"],
        "vehicle_label": f"{vehicle['year']} {vehicle['brand']} {vehicle['model']}",
        "vehicle": {
            "brand": vehicle["brand"],
            "model": vehicle["model"],
            "year": vehicle["year"],
            "mileage_km": vehicle["mileage_km"],
        },
        "insights": insights,
        "derived": {
            "event_ids": sorted(event["id"] for event in events),
            "parts_health": health_items,
            "predictions": predictions,
        },
    }


def generate_insights(demo_dir: Path) -> dict:
    vehicles, events_by_vehicle, parts_by_vehicle = _load_demo_data(demo_dir)
    vehicle_results = [
        _generate_vehicle_insights(
            vehicle,
            events_by_vehicle.get(vehicle["id"], []),
            parts_by_vehicle.get(vehicle["id"], []),
        )
        for vehicle in vehicles
    ]

    generated_at = datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    return {
        "schema_version": SCHEMA_VERSION,
        "model_version": MODEL_VERSION,
        "generated_at": generated_at,
        "source_files": sorted(ALLOWED_SOURCE_FILES),
        "vehicles_tested": len(vehicle_results),
        "vehicles": vehicle_results,
    }


def _known_refs(vehicle_result: dict) -> set[str]:
    refs = {f"vehicle:{vehicle_result['vehicle_id']}"}
    refs.update(f"event:{event_id}" for event_id in vehicle_result["derived"]["event_ids"])
    refs.update(f"part:{part['part_id']}" for part in vehicle_result["derived"]["parts_health"])
    refs.update(f"prediction:{prediction['id']}" for prediction in vehicle_result["derived"]["predictions"])
    return refs


def validate_insights(payload: dict) -> dict:
    failures = []
    category_counts = defaultdict(int)
    severity_counts = defaultdict(int)

    if payload.get("schema_version") != SCHEMA_VERSION:
        failures.append(f"Unexpected schema_version={payload.get('schema_version')}")

    if set(payload.get("source_files", [])) != ALLOWED_SOURCE_FILES:
        failures.append("Payload source_files do not match allowed demo data sources.")

    for vehicle_result in payload.get("vehicles", []):
        vehicle_id = vehicle_result["vehicle_id"]
        insights = vehicle_result.get("insights", [])
        refs = _known_refs(vehicle_result)

        if len(insights) < 3:
            failures.append(f"Vehicle {vehicle_id} has fewer than 3 insights.")
        if len(insights) > 3:
            failures.append(f"Vehicle {vehicle_id} has more than 3 insights.")

        categories = {insight.get("category") for insight in insights}
        missing_categories = REQUIRED_CATEGORIES - categories
        if missing_categories:
            failures.append(f"Vehicle {vehicle_id} is missing categories: {sorted(missing_categories)}.")

        for insight in insights:
            category_counts[insight["category"]] += 1
            severity_counts[insight["severity"]] += 1

            if not insight.get("message") or len(insight["message"].split()) < 10:
                failures.append(f"Vehicle {vehicle_id} insight {insight['id']} has a weak message.")

            lower_message = insight["message"].lower()
            jargon_found = sorted(word for word in TECHNICAL_JARGON if word in lower_message)
            if jargon_found:
                failures.append(
                    f"Vehicle {vehicle_id} insight {insight['id']} contains technical jargon: {jargon_found}."
                )

            if not insight.get("evidence"):
                failures.append(f"Vehicle {vehicle_id} insight {insight['id']} has no evidence.")

            for evidence in insight.get("evidence", []):
                ref = evidence.get("ref")
                if ref not in refs:
                    failures.append(f"Vehicle {vehicle_id} insight {insight['id']} has unknown ref {ref}.")

            source_files = set(insight.get("source_files", []))
            if not source_files or source_files - ALLOWED_SOURCE_FILES:
                failures.append(f"Vehicle {vehicle_id} insight {insight['id']} uses unsupported sources.")

    return {
        "passed": not failures,
        "failures": failures,
        "vehicles_tested": len(payload.get("vehicles", [])),
        "insights_tested": sum(len(vehicle.get("insights", [])) for vehicle in payload.get("vehicles", [])),
        "category_counts": dict(sorted(category_counts.items())),
        "severity_counts": dict(sorted(severity_counts.items())),
    }


def build_report(payload: dict, validation: dict, output_path: Path) -> str:
    lines = [
        "# Sample Vehicle Insights Validation Report",
        "",
        "## Summary",
        "",
        f"- Insights file: `{_relative(output_path)}`",
        f"- Schema version: `{payload['schema_version']}`",
        f"- Model version: `{payload['model_version']}`",
        f"- Vehicles tested: {validation['vehicles_tested']}",
        f"- Insights tested: {validation['insights_tested']}",
        f"- Validation status: {'passed' if validation['passed'] else 'failed'}",
        "",
        "## Source Data",
        "",
    ]

    for source_file in payload["source_files"]:
        lines.append(f"- `{source_file}`")

    lines.extend([
        "",
        "## Insight Coverage",
        "",
        "| Category | Count |",
        "| --- | ---: |",
    ])
    for category, count in validation["category_counts"].items():
        lines.append(f"| `{category}` | {count} |")

    lines.extend([
        "",
        "| Severity | Count |",
        "| --- | ---: |",
    ])
    for severity, count in validation["severity_counts"].items():
        lines.append(f"| `{severity}` | {count} |")

    lines.extend([
        "",
        "## Per-Vehicle Results",
        "",
        "| Vehicle | Insights | Categories | Top severity |",
        "| --- | ---: | --- | --- |",
    ])
    for vehicle in payload["vehicles"]:
        insights = vehicle["insights"]
        categories = ", ".join(insight["category"] for insight in insights)
        top_severity = sorted(
            {insight["severity"] for insight in insights},
            key=_risk_rank,
            reverse=True,
        )[0]
        lines.append(f"| {vehicle['vehicle_label']} | {len(insights)} | {categories} | {top_severity} |")

    lines.extend([
        "",
        "## Validation Rules",
        "",
        "- Each sample vehicle must have exactly 3 insights: maintenance, cost, and risk/prediction.",
        "- Every insight must include evidence tied to the sample vehicle, part, event, or derived prediction.",
        "- Insight source files must be limited to the provided demo CSV data.",
        "- Cost insights must not invent repair prices when the sample data has no non-zero costs.",
        "- Messages must be understandable to non-technical users and avoid low-level diagnostic jargon.",
        "",
        "## Failure Modes And Edge Cases",
        "",
        "- Demo cost fields are mostly zero, so the correct insight is limited-cost-data rather than a made-up estimate.",
        "- Recall rows are represented as service events in the sample data; insight logic treats recall titles/sources separately from normal service.",
        "- Reported complaint parts are not always supported by the parts-health rules, so risk/prediction insights use supported maintenance parts.",
        "- Rule-based predictions are estimates from sample mileage/service/part rows and must not be described as confirmed failures.",
        "",
    ])

    if validation["failures"]:
        lines.extend(["## Failures", ""])
        lines.extend(f"- {failure}" for failure in validation["failures"])
        lines.append("")

    lines.extend([
        "## Team Handoff Notes",
        "",
        "- Backend can use this JSON shape as a draft response contract for generated insights.",
        "- Frontend can render the three categories as separate cards or list rows per vehicle.",
        "- Product/QA should review the generated text for tone, but the current validation confirms source grounding and minimum coverage.",
        "",
    ])

    return "\n".join(lines)


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate and validate sample vehicle insights.")
    parser.add_argument("--demo-dir", default=DEFAULT_DEMO_DIR, type=Path)
    parser.add_argument("--output", default=DEFAULT_OUTPUT, type=Path)
    parser.add_argument("--report", default=DEFAULT_REPORT, type=Path)
    args = parser.parse_args()

    payload = generate_insights(args.demo_dir)
    validation = validate_insights(payload)
    write_json(args.output, payload)
    write_text(args.report, build_report(payload, validation, args.output))

    print(f"insights={args.output}")
    print(f"report={args.report}")
    print(f"validation={'passed' if validation['passed'] else 'failed'}")
    if validation["failures"]:
        for failure in validation["failures"]:
            print(f"- {failure}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
