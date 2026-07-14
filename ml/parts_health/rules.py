PART_HEALTH_MODEL_VERSION = "parts-health-v0.1"


COMPONENT_RULES = {
    "engine_oil": {
        "display_name": "Engine oil",
        "service_interval_km": 10000,
        "warning_km": 2000,
        "critical_km": 500,
        "repair_penalty": 5,
        "overdue_penalty_per_1000_km": 8,
        "recommendations": {
            "low": "Oil condition is healthy. Continue normal service schedule.",
            "medium": "Oil replacement will be required soon.",
            "high": "Replace engine oil as soon as possible.",
        },
    },
    "brake_pads": {
        "display_name": "Brake pads",
        "service_interval_km": 40000,
        "warning_km": 6000,
        "critical_km": 1500,
        "repair_penalty": 12,
        "overdue_penalty_per_1000_km": 6,
        "recommendations": {
            "low": "Brake pads are within normal wear range.",
            "medium": "Schedule brake inspection and prepare for replacement.",
            "high": "Inspect brake pads immediately and replace if needed.",
        },
    },
    "timing_belt": {
        "display_name": "Timing belt",
        "service_interval_km": 90000,
        "warning_km": 10000,
        "critical_km": 2500,
        "repair_penalty": 18,
        "overdue_penalty_per_1000_km": 10,
        "recommendations": {
            "low": "Timing belt is within expected service life.",
            "medium": "Plan timing belt replacement soon.",
            "high": "Immediate timing belt inspection and replacement are recommended.",
        },
    },
    "battery": {
        "display_name": "Battery",
        "service_interval_km": 60000,
        "warning_km": 8000,
        "critical_km": 2000,
        "repair_penalty": 10,
        "overdue_penalty_per_1000_km": 5,
        "recommendations": {
            "low": "Battery health is acceptable.",
            "medium": "Test battery capacity during the next service visit.",
            "high": "Battery replacement or charging system inspection is recommended.",
        },
    },
    "tires": {
        "display_name": "Tires",
        "service_interval_km": 50000,
        "warning_km": 7000,
        "critical_km": 2000,
        "repair_penalty": 14,
        "overdue_penalty_per_1000_km": 7,
        "recommendations": {
            "low": "Tire wear is within normal range.",
            "medium": "Inspect tire tread depth and rotation history.",
            "high": "Inspect and replace tires if tread depth is below safe threshold.",
        },
    },
    "air_filter": {
        "display_name": "Air filter",
        "service_interval_km": 20000,
        "warning_km": 4000,
        "critical_km": 1000,
        "repair_penalty": 4,
        "overdue_penalty_per_1000_km": 4,
        "recommendations": {
            "low": "Air filter is within normal service interval.",
            "medium": "Replace air filter at the next planned service.",
            "high": "Replace air filter soon to avoid performance degradation.",
        },
    },
}


PART_ALIASES = {
    "oil": "engine_oil",
    "engine oil": "engine_oil",
    "engine_oil": "engine_oil",
    "brakes": "brake_pads",
    "brake pads": "brake_pads",
    "brake_pads": "brake_pads",
    "timing belt": "timing_belt",
    "timing_belt": "timing_belt",
    "battery": "battery",
    "tires": "tires",
    "tyres": "tires",
    "air filter": "air_filter",
    "air_filter": "air_filter",
}


RISK_LEVELS = {
    "low": {
        "min_health_score": 75,
        "max_health_score": 100,
        "description": "Component is healthy or only lightly worn.",
    },
    "medium": {
        "min_health_score": 40,
        "max_health_score": 74,
        "description": "Component is wearing out and should be monitored or serviced soon.",
    },
    "high": {
        "min_health_score": 0,
        "max_health_score": 39,
        "description": "Component is overdue, close to failure, or predicted as high risk.",
    },
}


def normalize_part_category(part_category):
    if not part_category:
        raise ValueError("part_category is required")

    normalized = str(part_category).strip().lower().replace("-", "_")
    normalized = PART_ALIASES.get(normalized, normalized)

    if normalized not in COMPONENT_RULES:
        supported = ", ".join(sorted(COMPONENT_RULES))
        raise ValueError(f"Unsupported part_category={part_category}. Supported: {supported}")

    return normalized
