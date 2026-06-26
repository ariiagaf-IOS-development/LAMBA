from typing import Any, Dict, List, Optional


def confidence_qualifier(probability: float) -> str:
    if probability >= 0.75:
        return "high"
    if probability >= 0.55:
        return "medium"
    return "low"


def confidence_label(probability: float) -> str:
    qualifier = confidence_qualifier(probability)
    return f"{qualifier.capitalize()} confidence"


def _factor(
    name: str,
    value: Any,
    impact: str,
    weight: float,
    description: str,
) -> dict:
    return {
        "name": name,
        "value": str(value),
        "impact": impact,
        "weight": round(weight, 2),
        "description": description,
    }


def build_prediction_explanation(
    *,
    model_version: str,
    model_name: str,
    part_name: str,
    risk_level: str,
    risk_score: int,
    remaining_km: Optional[int],
    probability: float,
    recommendation: str,
    feature_row: Dict[str, Any],
) -> dict:
    factors: List[dict] = [
        _factor(
            "risk_score",
            risk_score,
            risk_level,
            0.35,
            "Normalized maintenance risk score produced by the selected baseline model.",
        ),
        _factor(
            "remaining_km",
            "unknown" if remaining_km is None else f"{remaining_km} km",
            risk_level,
            0.25,
            "Estimated distance before the next recommended maintenance action.",
        ),
        _factor(
            "maintenance_history_quality",
            feature_row.get("maintenance_history_quality", "unknown"),
            "low" if feature_row.get("maintenance_history_quality") == "good" else "medium",
            0.15,
            "Service history quality derived from available maintenance events.",
        ),
        _factor(
            "km_since_last_maintenance",
            f"{feature_row.get('km_since_last_maintenance', 0)} km",
            "medium",
            0.15,
            "Distance accumulated since the latest maintenance event in the timeline.",
        ),
        _factor(
            "repair_event_count",
            feature_row.get("repair_event_count", 0),
            "medium" if feature_row.get("repair_event_count", 0) else "low",
            0.10,
            "Number of repair events considered as reliability context.",
        ),
    ]

    explanation_text = (
        f"{model_version} ({model_name}) predicts {risk_level} risk for {part_name}. "
        f"The score is {risk_score}/100"
    )
    if remaining_km is not None:
        explanation_text += f" with about {remaining_km} km remaining"
    explanation_text += "."

    return {
        "explanation_text": explanation_text,
        "confidence": confidence_label(probability),
        "confidence_qualifier": confidence_qualifier(probability),
        "confidence_score": round(float(probability), 4),
        "factors": factors,
        "recommended_action": recommendation,
    }
