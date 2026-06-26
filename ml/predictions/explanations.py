from typing import Any, Dict, List, Optional


RISK_LABELS = {
    "low": "low",
    "medium": "medium",
    "high": "high",
}

USAGE_LABELS = {
    "city": "city driving",
    "highway": "highway driving",
    "mixed": "mixed driving",
    "commercial": "commercial use",
    "personal": "personal use",
}


def confidence_qualifier(probability: float) -> str:
    if probability >= 0.75:
        return "high"
    if probability >= 0.55:
        return "medium"
    return "low"


def confidence_label(probability: float) -> str:
    qualifier = confidence_qualifier(probability)
    labels = {
        "high": "High confidence",
        "medium": "Medium confidence",
        "low": "Low confidence",
    }
    return labels[qualifier]


def format_probability(probability: float) -> str:
    return f"{probability * 100:.1f}%"


def format_remaining_km(remaining_km: Optional[int]) -> str:
    if remaining_km is None:
        return "the remaining distance is not available yet"
    return f"about {remaining_km:,} km"


def risk_label(risk_level: str) -> str:
    return RISK_LABELS.get(risk_level, risk_level)


def driving_profile_label(feature_row: Dict[str, Any]) -> str:
    usage_type = str(feature_row.get("usage_type") or "mixed").lower()
    return USAGE_LABELS.get(usage_type, usage_type)


def recommended_action_text(risk_level: str, part_name: str, fallback: str) -> str:
    if risk_level == "high":
        return f"Inspect {part_name} as soon as possible."
    if risk_level == "medium":
        return f"Schedule inspection for {part_name} soon."
    if risk_level == "low":
        return f"{part_name} looks stable; continue planned maintenance."
    return fallback


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
    km_since_last_service = feature_row.get("km_since_last_maintenance", 0)
    usage_profile = driving_profile_label(feature_row)
    community_value = (
        f"similar to demo-data vehicles in the "
        f"{feature_row.get('mileage_bucket', 'unknown')}"
        " mileage bucket"
    )
    risk_text = risk_label(risk_level)
    probability_text = format_probability(probability)
    remaining_text = format_remaining_km(remaining_km)
    action_text = recommended_action_text(risk_level, part_name, recommendation)

    factors: List[dict] = [
        _factor(
            "km_since_last_service",
            f"{km_since_last_service} km",
            risk_level,
            0.40,
            "Distance since the last service increases the chance of upcoming maintenance.",
        ),
        _factor(
            "driving_profile",
            usage_profile,
            "medium" if usage_profile != "highway driving" else "low",
            0.30,
            "Driving profile helps estimate the load placed on the part.",
        ),
        _factor(
            "community_data",
            community_value,
            "medium",
            0.20,
            "Comparison with similar vehicles in the available demo dataset refines the forecast.",
        ),
        _factor(
            "model_probability",
            probability_text,
            risk_level,
            0.10,
            "Model probability shows how strongly the model selected this risk level.",
        ),
    ]

    explanation_text = (
        f"For {part_name}, model {model_version} ({model_name}) predicts {risk_text} risk: "
        f"{risk_score}/100. Prediction confidence is {probability_text}, and the estimated "
        f"distance until the next service is {remaining_text}. Key reasons: "
        f"{km_since_last_service} km since the last service, {usage_profile}, and similar "
        f"vehicles in the demo dataset support this risk level."
    )

    return {
        "explanation_text": explanation_text,
        "confidence": confidence_label(probability),
        "confidence_qualifier": confidence_qualifier(probability),
        "confidence_score": round(float(probability), 4),
        "factors": factors,
        "recommended_action": action_text,
    }
