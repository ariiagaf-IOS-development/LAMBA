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

PART_CATEGORY_ALIASES = {
    "oil": "engine_oil",
    "engine oil": "engine_oil",
    "brakes": "brake_pads",
    "brake pads": "brake_pads",
    "timing belt": "timing_belt",
    "air filter": "air_filter",
}

PART_RECOMMENDATIONS = {
    "engine_oil": {
        "low": "Continue the normal oil service schedule and monitor mileage.",
        "medium": "Schedule an oil and oil filter change soon.",
        "high": "Replace the engine oil and oil filter as soon as possible.",
    },
    "brake_pads": {
        "low": "Continue routine brake checks during planned maintenance.",
        "medium": "Schedule a brake inspection soon and prepare for pad replacement.",
        "high": "Arrange an immediate brake inspection and replace worn pads before further driving.",
    },
    "battery": {
        "low": "Continue routine battery checks during planned maintenance.",
        "medium": "Test battery capacity and the charging system at the next service visit.",
        "high": "Have the battery and charging system inspected immediately and replace the battery if required.",
    },
    "tires": {
        "low": "Continue routine tire pressure, tread, and rotation checks.",
        "medium": "Inspect tread depth, pressure, and wear soon; rotate or replace tires as needed.",
        "high": "Arrange an immediate tire inspection and replace unsafe tires before further driving.",
    },
    "air_filter": {
        "low": "Continue the normal air filter inspection schedule.",
        "medium": "Inspect and replace the air filter at the next planned service.",
        "high": "Replace the air filter soon to avoid further airflow and performance degradation.",
    },
    "timing_belt": {
        "low": "Continue the normal timing belt inspection and replacement schedule.",
        "medium": "Schedule a timing belt inspection and plan replacement soon.",
        "high": "Arrange an immediate timing belt inspection and replacement; do not delay service.",
    },
}

DEFAULT_RECOMMENDATIONS = {
    "low": "{part_name} looks stable; continue planned maintenance.",
    "medium": "Schedule inspection for {part_name} soon.",
    "high": "Inspect {part_name} as soon as possible.",
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


def normalize_part_category(part_category: Optional[str], part_name: str) -> str:
    value = str(part_category or part_name).strip().lower().replace("-", "_")
    return PART_CATEGORY_ALIASES.get(value, value)


def recommendation_for(
    risk_level: str,
    part_name: str,
    part_category: Optional[str] = None,
    fallback: str = "",
) -> str:
    category = normalize_part_category(part_category, part_name)
    recommendation = PART_RECOMMENDATIONS.get(category, {}).get(risk_level)
    if recommendation:
        return recommendation

    default = DEFAULT_RECOMMENDATIONS.get(risk_level)
    if default:
        return default.format(part_name=part_name)
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
    part_category: Optional[str] = None,
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
    action_text = recommendation_for(
        risk_level,
        part_name,
        part_category=part_category,
        fallback=recommendation,
    )

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
            f"The model assigned a {probability_text} probability to the "
            f"{risk_text}-risk class.",
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
