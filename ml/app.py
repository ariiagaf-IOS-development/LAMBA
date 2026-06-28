import logging
from pathlib import Path

import joblib
from fastapi import FastAPI

from predictions.fallback import generate_fallback_predictions
from predictions.explanations import build_prediction_explanation, recommendation_for
from predictions.schemas import PredictionRequestSchema, PredictionResponseSchema
from training.inference_maintenance_model import predict_row

logger = logging.getLogger("lamba-ml")

ARTIFACT_PATH = Path(__file__).parent / "training" / "artifacts" / "maintenance_risk_model.joblib"

app = FastAPI(title="LAMBA ML Service")

_model_artifact = None


def _load_model():
    global _model_artifact
    if ARTIFACT_PATH.exists():
        try:
            _model_artifact = joblib.load(ARTIFACT_PATH)
            logger.info("loaded model artifact: %s", _model_artifact.get("model_version"))
        except Exception:
            logger.exception("failed to load model artifact, will use fallback")
            _model_artifact = None
    else:
        logger.warning("model artifact not found at %s, will use fallback", ARTIFACT_PATH)


@app.on_event("startup")
def startup():
    _load_model()


@app.get("/health")
def health():
    return {
        "status": "ok",
        "model_loaded": _model_artifact is not None,
        "model_version": _model_artifact.get("model_version") if _model_artifact else None,
    }


def _build_feature_row(request: PredictionRequestSchema) -> dict:
    v = request.vehicle
    events = [e.model_dump() for e in request.events]
    parts = [p.model_dump() for p in request.parts]

    maintenance_events = [e for e in events if e["type"] in ("maintenance", "service")]
    repair_events = [e for e in events if e["type"] == "repair"]
    refuel_events = [e for e in events if e["type"] == "refuel"]

    km_since_last_maintenance = 0
    if maintenance_events:
        last_maint_km = max(e.get("mileage_km") or 0 for e in maintenance_events)
        km_since_last_maintenance = max(0, v.mileage_km - last_maint_km)

    km_since_last_repair = 0
    repair_cost_total = 0.0
    if repair_events:
        last_repair_km = max(e.get("mileage_km") or 0 for e in repair_events)
        km_since_last_repair = max(0, v.mileage_km - last_repair_km)
        repair_cost_total = sum(e.get("cost") or 0 for e in repair_events)

    km_since_last_refuel = 0
    if refuel_events:
        last_refuel_km = max(e.get("mileage_km") or 0 for e in refuel_events)
        km_since_last_refuel = max(0, v.mileage_km - last_refuel_km)

    avg_part_age_km = 0.0
    avg_km_since_part_service = 0.0
    if parts:
        ages = []
        service_dists = []
        for p in parts:
            installed = p.get("installed_at_mileage_km")
            if installed is not None:
                ages.append(v.mileage_km - installed)
            last_svc = p.get("last_service_mileage_km")
            if last_svc is not None:
                service_dists.append(v.mileage_km - last_svc)
        if ages:
            avg_part_age_km = sum(ages) / len(ages)
        if service_dists:
            avg_km_since_part_service = sum(service_dists) / len(service_dists)

    mileage = v.mileage_km
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
        mh_quality = "good"
        mh_score = 2
    elif service_count >= 2:
        mh_quality = "average"
        mh_score = 1
    else:
        mh_quality = "poor"
        mh_score = 0

    return {
        "vehicle_id": v.id,
        "vehicle_age_years": max(0, 2026 - v.year),
        "mileage_km": v.mileage_km,
        "mileage_bucket": mileage_bucket,
        "brand": v.brand,
        "model": v.model,
        "body_class": "Sedan/Saloon",
        "fuel_type": v.fuel_type or "Gasoline",
        "transmission": v.transmission or "automatic",
        "usage_type": v.usage_type or "mixed",
        "maintenance_event_count": len(maintenance_events),
        "service_count_source": service_count,
        "maintenance_history_quality": mh_quality,
        "maintenance_history_score": mh_score,
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


def _model_predict(request: PredictionRequestSchema) -> dict:
    row = _build_feature_row(request)
    result = predict_row(_model_artifact, row)

    prob_map = result.get("probability_by_risk_level", {})
    probability = prob_map.get(result["risk_level"], result["risk_score"] / 100)

    predictions = []
    parts = [p.model_dump() for p in request.parts]
    if not parts:
        parts = [{"part_category": "general", "part_name": "Vehicle overall"}]

    for part in parts:
        part_name = part.get("part_name", "Unknown")
        part_category = part.get("part_category", "general")
        recommendation = recommendation_for(
            result["risk_level"],
            part_name,
            part_category=part_category,
        )
        explanation_details = build_prediction_explanation(
            model_version=_model_artifact["model_version"],
            model_name=_model_artifact["selected_model"],
            part_name=part_name,
            part_category=part_category,
            risk_level=result["risk_level"],
            risk_score=result["risk_score"],
            remaining_km=result["remaining_km"],
            probability=float(probability),
            recommendation=recommendation,
            feature_row=row,
        )
        predictions.append({
            "part_category": part_category,
            "part_name": part_name,
            "risk_level": result["risk_level"],
            "risk_score": result["risk_score"],
            "remaining_km": result["remaining_km"],
            "remaining_days": None,
            "predicted_next_mileage": request.vehicle.mileage_km + result["remaining_km"],
            "predicted_next_date": None,
            "probability": round(float(probability), 4),
            "recommendation": recommendation,
            "explanation": explanation_details["explanation_text"],
            "explanation_details": explanation_details,
        })

    return {
        "vehicle_id": request.vehicle.id,
        "model_version": _model_artifact["model_version"],
        "predictions": predictions,
    }

@app.post("/predict", response_model=PredictionResponseSchema)
def predict(request: PredictionRequestSchema):
    if _model_artifact is not None:
        try:
            return _model_predict(request)
        except Exception:
            logger.exception("model prediction failed, using fallback")

    payload = request.model_dump()
    return generate_fallback_predictions(payload)
