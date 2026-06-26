try:
    from ml.parts_health.health_model import calculate_component_health
    from ml.predictions.explanations import build_prediction_explanation
except ImportError:
    from parts_health.health_model import calculate_component_health
    from predictions.explanations import build_prediction_explanation


FALLBACK_MODEL_VERSION = "fallback-maintenance-v1.0.0"


def generate_fallback_predictions(payload: dict) -> dict:
    vehicle = payload["vehicle"]
    events = payload.get("events", [])
    parts = payload.get("parts", [])

    service_history = [
        event
        for event in events
        if event.get("type") in {"service", "maintenance"}
    ]

    repair_history = [
        event
        for event in events
        if event.get("type") == "repair"
    ]

    predictions = []

    for part in parts:
        health = calculate_component_health(
            part_category=part["part_category"],
            current_mileage_km=vehicle["mileage_km"],
            service_history=service_history,
            repair_history=repair_history,
            prediction_outputs=[],
            installed_at_mileage_km=part.get("installed_at_mileage_km"),
            last_service_mileage_km=part.get("last_service_mileage_km"),
        )

        risk_score = 100 - health["health_score"]
        risk_score = max(0, min(100, risk_score))

        remaining_km = health.get("remaining_km")

        if remaining_km is not None:
            predicted_next_mileage = vehicle["mileage_km"] + max(remaining_km, 0)
        else:
            predicted_next_mileage = None

        predictions.append(
            {
                "part_category": health["part_category"],
                "part_name": health["part_name"],
                "risk_level": health["risk_level"],
                "risk_score": risk_score,
                "remaining_km": remaining_km,
                "remaining_days": None,
                "predicted_next_mileage": predicted_next_mileage,
                "predicted_next_date": None,
                "probability": round(risk_score / 100, 2),
                "recommendation": health["recommendation"],
                "explanation": (
                    "Fallback prediction was generated using the Parts Health Model "
                    "because the ML prediction service was unavailable."
                ),
                "explanation_details": build_prediction_explanation(
                    model_version=FALLBACK_MODEL_VERSION,
                    model_name="parts_health_fallback",
                    part_name=health["part_name"],
                    risk_level=health["risk_level"],
                    risk_score=risk_score,
                    remaining_km=remaining_km,
                    probability=risk_score / 100,
                    recommendation=health["recommendation"],
                    feature_row={
                        "maintenance_history_quality": "fallback",
                        "km_since_last_maintenance": 0,
                        "repair_event_count": len(repair_history),
                    },
                ),
            }
        )

    return {
        "vehicle_id": vehicle["id"],
        "model_version": FALLBACK_MODEL_VERSION,
        "predictions": predictions,
    }
