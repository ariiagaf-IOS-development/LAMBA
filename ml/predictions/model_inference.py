#!/usr/bin/env python3

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import joblib


ML_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = ML_ROOT.parent
DEFAULT_ARTIFACT = ML_ROOT / "training" / "artifacts" / "maintenance_risk_model.joblib"
DEFAULT_REQUEST = ML_ROOT / "predictions" / "example_predict_request.json"
DEFAULT_OUTPUT = ML_ROOT / "predictions" / "example_model_predictions.json"

if str(ML_ROOT) not in sys.path:
    sys.path.insert(0, str(ML_ROOT))

from predictions.schemas import (  # noqa: E402
    PredictionRequestSchema,
    PredictionResponseSchema,
)
from predictions.explanations import build_prediction_explanation  # noqa: E402
from training.inference_maintenance_model import predict_row  # noqa: E402


def _dump_model(model: Any) -> dict:
    if hasattr(model, "model_dump"):
        return model.model_dump()
    return model.dict()


def load_request(path: Path) -> PredictionRequestSchema:
    with open(path, "r", encoding="utf-8") as request_file:
        return PredictionRequestSchema(**json.load(request_file))


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as output_file:
        json.dump(payload, output_file, indent=2, default=str)
        output_file.write("\n")


def build_feature_row(request: PredictionRequestSchema) -> dict:
    vehicle = request.vehicle
    events = [_dump_model(event) for event in request.events]
    parts = [_dump_model(part) for part in request.parts]

    maintenance_events = [event for event in events if event["type"] in ("maintenance", "service")]
    repair_events = [event for event in events if event["type"] == "repair"]
    refuel_events = [event for event in events if event["type"] == "refuel"]

    km_since_last_maintenance = 0
    if maintenance_events:
        last_maintenance_km = max(event.get("mileage_km") or 0 for event in maintenance_events)
        km_since_last_maintenance = max(0, vehicle.mileage_km - last_maintenance_km)

    km_since_last_repair = 0
    repair_cost_total = 0.0
    if repair_events:
        last_repair_km = max(event.get("mileage_km") or 0 for event in repair_events)
        km_since_last_repair = max(0, vehicle.mileage_km - last_repair_km)
        repair_cost_total = sum(event.get("cost") or 0 for event in repair_events)

    km_since_last_refuel = 0
    if refuel_events:
        last_refuel_km = max(event.get("mileage_km") or 0 for event in refuel_events)
        km_since_last_refuel = max(0, vehicle.mileage_km - last_refuel_km)

    avg_part_age_km = 0.0
    avg_km_since_part_service = 0.0
    if parts:
        ages = []
        service_distances = []
        for part in parts:
            installed_at = part.get("installed_at_mileage_km")
            if installed_at is not None:
                ages.append(vehicle.mileage_km - installed_at)

            last_service = part.get("last_service_mileage_km")
            if last_service is not None:
                service_distances.append(vehicle.mileage_km - last_service)

        if ages:
            avg_part_age_km = sum(ages) / len(ages)
        if service_distances:
            avg_km_since_part_service = sum(service_distances) / len(service_distances)

    mileage = vehicle.mileage_km
    if mileage < 30000:
        mileage_bucket = "low"
    elif mileage < 80000:
        mileage_bucket = "medium"
    elif mileage < 150000:
        mileage_bucket = "high"
    else:
        mileage_bucket = "very_high"

    service_count = len(maintenance_events)
    if service_count >= 5:
        maintenance_history_quality = "good"
        maintenance_history_score = 2
    elif service_count >= 2:
        maintenance_history_quality = "average"
        maintenance_history_score = 1
    else:
        maintenance_history_quality = "poor"
        maintenance_history_score = 0

    return {
        "vehicle_id": vehicle.id,
        "vehicle_age_years": max(0, 2026 - vehicle.year),
        "mileage_km": vehicle.mileage_km,
        "mileage_bucket": mileage_bucket,
        "brand": vehicle.brand,
        "model": vehicle.model,
        "body_class": "Sedan/Saloon",
        "fuel_type": vehicle.fuel_type or "Gasoline",
        "transmission": vehicle.transmission or "automatic",
        "usage_type": vehicle.usage_type or "mixed",
        "maintenance_event_count": len(maintenance_events),
        "service_count_source": service_count,
        "maintenance_history_quality": maintenance_history_quality,
        "maintenance_history_score": maintenance_history_score,
        "km_since_last_maintenance": km_since_last_maintenance,
        "repair_event_count": len(repair_events),
        "km_since_last_repair": km_since_last_repair,
        "repair_cost_total": repair_cost_total,
        "refuel_event_count": len(refuel_events),
        "km_since_last_refuel": km_since_last_refuel,
        "fuel_efficiency_km_per_liter": 12.0,
        "tracked_part_count": len(parts),
        "avg_part_age_km": round(avg_part_age_km, 2),
        "avg_km_since_part_service": round(avg_km_since_part_service, 2),
    }


def recommendation_for(risk_level: str, part_name: str) -> str:
    if risk_level == "high":
        return f"Inspect {part_name} as soon as possible."
    if risk_level == "medium":
        return f"Schedule inspection for {part_name} soon."
    return f"{part_name} looks stable; continue planned maintenance."


def predict_response(artifact: dict, request: PredictionRequestSchema) -> PredictionResponseSchema:
    row = build_feature_row(request)
    result = predict_row(artifact, row)

    probability_by_risk = result.get("probability_by_risk_level", {})
    probability = probability_by_risk.get(result["risk_level"], result["risk_score"] / 100)
    parts = [_dump_model(part) for part in request.parts]
    if not parts:
        parts = [{"part_category": "general", "part_name": "Vehicle overall"}]

    predictions = []
    for part in parts:
        part_name = part.get("part_name") or "Unknown"
        remaining_km = result["remaining_km"]
        recommendation = recommendation_for(result["risk_level"], part_name)
        explanation_details = build_prediction_explanation(
            model_version=artifact["model_version"],
            model_name=artifact["selected_model"],
            part_name=part_name,
            risk_level=result["risk_level"],
            risk_score=result["risk_score"],
            remaining_km=remaining_km,
            probability=float(probability),
            recommendation=recommendation,
            feature_row=row,
        )
        predictions.append({
            "part_category": part.get("part_category") or "general",
            "part_name": part_name,
            "risk_level": result["risk_level"],
            "risk_score": result["risk_score"],
            "remaining_km": remaining_km,
            "remaining_days": None,
            "predicted_next_mileage": request.vehicle.mileage_km + remaining_km,
            "predicted_next_date": None,
            "probability": round(float(probability), 4),
            "recommendation": recommendation,
            "explanation": explanation_details["explanation_text"],
            "explanation_details": explanation_details,
        })

    return PredictionResponseSchema(
        vehicle_id=request.vehicle.id,
        model_version=artifact["model_version"],
        predictions=predictions,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate backend-compatible model prediction response.")
    parser.add_argument("--artifact", default=DEFAULT_ARTIFACT, type=Path)
    parser.add_argument("--request", default=DEFAULT_REQUEST, type=Path)
    parser.add_argument("--output", default=DEFAULT_OUTPUT, type=Path)
    args = parser.parse_args()

    artifact = joblib.load(args.artifact)
    request = load_request(args.request)
    response = predict_response(artifact, request)
    write_json(args.output, _dump_model(response))

    print(f"output={args.output}")


if __name__ == "__main__":
    main()
