from datetime import date, datetime

try:
    from .rules import COMPONENT_RULES, PART_HEALTH_MODEL_VERSION, normalize_part_category
except ImportError:
    from rules import COMPONENT_RULES, PART_HEALTH_MODEL_VERSION, normalize_part_category


def clamp(value, min_value=0, max_value=100):
    return max(min_value, min(max_value, value))


def risk_level_from_health_score(health_score):
    if health_score >= 75:
        return "low"
    if health_score >= 40:
        return "medium"
    return "high"


def _parse_date(value):
    if value is None or isinstance(value, date):
        return value
    return datetime.fromisoformat(str(value).replace("Z", "+00:00")).date()


def _latest_mileage(records, event_types):
    latest = None
    for record in records or []:
        event_type = str(record.get("type", "")).lower()
        if event_type not in event_types:
            continue
        mileage = record.get("mileage_km")
        if mileage is None:
            continue
        latest = max(latest or 0, int(mileage))
    return latest


def _recent_repair_count(records, part_category, current_mileage_km, window_km):
    count = 0
    for record in records or []:
        event_type = str(record.get("type", "")).lower()
        if event_type != "repair":
            continue

        metadata = record.get("metadata") or {}
        event_part = metadata.get("part_category") or metadata.get("part_name") or record.get("title")
        if event_part and part_category.replace("_", " ") not in str(event_part).lower().replace("_", " "):
            continue

        mileage = record.get("mileage_km")
        if mileage is None or current_mileage_km - int(mileage) <= window_km:
            count += 1
    return count


def _prediction_for_part(prediction_outputs, part_category):
    for prediction in prediction_outputs or []:
        prediction_part = (
            prediction.get("part_category")
            or prediction.get("part_name")
            or prediction.get("component")
        )
        if prediction_part and part_category.replace("_", " ") in str(prediction_part).lower().replace("_", " "):
            return prediction
    return {}


def _score_from_remaining_km(remaining_km, rule):
    interval = rule["service_interval_km"]
    warning = rule["warning_km"]
    critical = rule["critical_km"]

    if remaining_km is None:
        return 70
    if remaining_km <= 0:
        overdue_km = abs(remaining_km)
        overdue_penalty = (overdue_km / 1000) * rule["overdue_penalty_per_1000_km"]
        return clamp(30 - overdue_penalty)
    if remaining_km <= critical:
        return 35
    if remaining_km <= warning:
        return 55 + (remaining_km / warning) * 20
    return 75 + min(25, (remaining_km / interval) * 25)


def _score_from_prediction(prediction):
    if not prediction:
        return 75

    probability = prediction.get("probability")
    risk_score = prediction.get("risk_score")
    risk_level = prediction.get("risk_level")

    if risk_score is not None:
        return clamp(100 - int(risk_score))
    if probability is not None:
        return clamp(100 - round(float(probability) * 100))
    if risk_level == "high":
        return 25
    if risk_level == "medium":
        return 55
    return 85


def calculate_component_health(
    part_category,
    current_mileage_km,
    service_history=None,
    repair_history=None,
    prediction_outputs=None,
    installed_at_mileage_km=None,
    last_service_mileage_km=None,
):
    part_category = normalize_part_category(part_category)
    rule = COMPONENT_RULES[part_category]
    current_mileage_km = int(current_mileage_km)

    latest_service_mileage = last_service_mileage_km
    history_service_mileage = _latest_mileage(service_history, {"service", "maintenance"})
    if history_service_mileage is not None:
        latest_service_mileage = max(latest_service_mileage or 0, history_service_mileage)

    baseline_mileage = latest_service_mileage
    if baseline_mileage is None:
        baseline_mileage = installed_at_mileage_km
    if baseline_mileage is None:
        baseline_mileage = 0

    mileage_since_service = max(0, current_mileage_km - int(baseline_mileage))
    remaining_km = rule["service_interval_km"] - mileage_since_service

    mileage_score = _score_from_remaining_km(remaining_km, rule)
    service_score = 100 if latest_service_mileage is not None else 60

    repair_count = _recent_repair_count(
        repair_history,
        part_category,
        current_mileage_km,
        window_km=rule["service_interval_km"],
    )
    repair_score = clamp(100 - repair_count * rule["repair_penalty"])

    prediction = _prediction_for_part(prediction_outputs, part_category)
    prediction_score = _score_from_prediction(prediction)

    health_score = round(
        mileage_score * 0.40
        + service_score * 0.20
        + repair_score * 0.15
        + prediction_score * 0.25
    )
    health_score = clamp(health_score)
    risk_level = risk_level_from_health_score(health_score)

    return {
        "model_version": PART_HEALTH_MODEL_VERSION,
        "part_category": part_category,
        "part_name": rule["display_name"],
        "health_score": health_score,
        "risk_level": risk_level,
        "current_mileage_km": current_mileage_km,
        "mileage_since_service_km": mileage_since_service,
        "remaining_km": remaining_km,
        "inputs": {
            "mileage": {
                "current_mileage_km": current_mileage_km,
                "installed_at_mileage_km": installed_at_mileage_km,
                "last_service_mileage_km": latest_service_mileage,
            },
            "service_history": service_history or [],
            "repair_history": repair_history or [],
            "prediction_outputs": prediction_outputs or [],
        },
        "score_breakdown": {
            "mileage_score": round(mileage_score),
            "service_score": round(service_score),
            "repair_score": round(repair_score),
            "prediction_score": round(prediction_score),
            "weights": {
                "mileage": 0.40,
                "service_history": 0.20,
                "repair_history": 0.15,
                "prediction_outputs": 0.25,
            },
        },
        "recommendation": rule["recommendations"][risk_level],
    }


def calculate_vehicle_parts_health(vehicle):
    current_mileage_km = vehicle["vehicle"]["mileage_km"]
    service_history = [event for event in vehicle.get("events", []) if event.get("type") in {"service", "maintenance"}]
    repair_history = [event for event in vehicle.get("events", []) if event.get("type") == "repair"]
    prediction_outputs = vehicle.get("predictions", [])

    results = []
    for part in vehicle.get("parts", []):
        results.append(
            calculate_component_health(
                part_category=part["part_category"],
                current_mileage_km=current_mileage_km,
                service_history=service_history,
                repair_history=repair_history,
                prediction_outputs=prediction_outputs,
                installed_at_mileage_km=part.get("installed_at_mileage_km"),
                last_service_mileage_km=part.get("last_service_mileage_km"),
            )
        )
    return {
        "vehicle_id": vehicle["vehicle"]["id"],
        "model_version": PART_HEALTH_MODEL_VERSION,
        "parts_health": results,
    }
