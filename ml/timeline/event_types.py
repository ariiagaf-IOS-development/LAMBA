from enum import Enum


class TimelineEventType(str, Enum):
    trip = "trip"
    refuel = "refuel"
    repair = "repair"
    service = "service"
    inspection = "inspection"
    accident = "accident"
    recall = "recall"
    warning = "warning"
    maintenance = "maintenance"
    prediction = "prediction"
    diagnostic = "diagnostic"
    part_replacement = "part_replacement"
    note = "note"


CANONICAL_EVENT_TYPES = {
    TimelineEventType.trip.value,
    TimelineEventType.refuel.value,
    TimelineEventType.repair.value,
    TimelineEventType.inspection.value,
    TimelineEventType.accident.value,
    TimelineEventType.recall.value,
    TimelineEventType.warning.value,
    TimelineEventType.maintenance.value,
    TimelineEventType.prediction.value,
    TimelineEventType.diagnostic.value,
    TimelineEventType.part_replacement.value,
    TimelineEventType.note.value,
}


LEGACY_EVENT_TYPE_ALIASES = {
    "service": TimelineEventType.maintenance.value,
}


SUPPORTED_EVENT_TYPES = CANONICAL_EVENT_TYPES | set(LEGACY_EVENT_TYPE_ALIASES)


TIMELINE_EVENT_SCHEMA = {
    "id": "integer",
    "vehicle_id": "integer",
    "type": "trip | refuel | repair | inspection | accident | recall | warning | maintenance | prediction | diagnostic | part_replacement | note",
    "title": "string",
    "description": "string | null",
    "mileage_km": "integer | null",
    "cost": "number | null",
    "event_date": "datetime string",
    "metadata": "object | null",
}


def normalize_event_type(event_type):
    if not event_type:
        raise ValueError("event_type is required")

    normalized = str(event_type).strip().lower().replace("-", "_")
    return LEGACY_EVENT_TYPE_ALIASES.get(normalized, normalized)


def is_supported_event_type(event_type):
    return normalize_event_type(event_type) in CANONICAL_EVENT_TYPES
