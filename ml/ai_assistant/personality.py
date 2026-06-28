import json
from pathlib import Path
from typing import Any


AI_ASSISTANT_DIR = Path(__file__).resolve().parent
PERSONALITY_PROFILES_PATH = AI_ASSISTANT_DIR / "personality_profiles.json"


def load_personality_profiles(path: Path = PERSONALITY_PROFILES_PATH) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _metadata_profile(vehicle: dict[str, Any]) -> str | None:
    metadata = vehicle.get("metadata") or {}
    if not isinstance(metadata, dict):
        return None

    for key in ("personality_profile", "assistant_personality", "voice_profile"):
        value = metadata.get(key)
        if isinstance(value, str) and value:
            return value.strip().lower()

    return None


def _metadata_value(vehicle: dict[str, Any], *keys: str) -> str:
    metadata = vehicle.get("metadata") or {}
    if not isinstance(metadata, dict):
        metadata = {}

    for key in keys:
        value = metadata.get(key)
        if isinstance(value, str) and value:
            return value.strip().lower()

    return ""


def _vehicle_age_years(vehicle: dict[str, Any]) -> int | None:
    metadata = vehicle.get("metadata") or {}
    if not isinstance(metadata, dict):
        metadata = {}

    age_value = metadata.get("age_years")
    if isinstance(age_value, int):
        return age_value
    if isinstance(age_value, str) and age_value.isdigit():
        return int(age_value)

    year = vehicle.get("year") or metadata.get("production_year")
    if isinstance(year, int):
        return max(0, 2026 - year)
    if isinstance(year, str) and year.isdigit():
        return max(0, 2026 - int(year))

    return None


def _profile_or_default(profile_id: str, profiles: dict[str, Any], default_profile: str) -> str:
    return profile_id if profile_id in profiles else default_profile


def infer_personality_profile(context: dict[str, Any], profiles_config: dict[str, Any] | None = None) -> str:
    profiles_config = profiles_config or load_personality_profiles()
    profiles = profiles_config.get("profiles", {})
    default_profile = profiles_config.get("default_profile", "friendly")

    vehicle = context.get("vehicle", {})
    configured_profile = _metadata_profile(vehicle)
    if configured_profile in profiles:
        return configured_profile

    color = _metadata_value(vehicle, "color", "paint_color", "exterior_color")
    vehicle_type = _metadata_value(vehicle, "vehicle_type", "body_type", "usage_type", "segment")
    age_group = _metadata_value(vehicle, "age_group", "vehicle_age_group")
    age_years = _vehicle_age_years(vehicle)

    if color in {"pink", "rose", "rose pink", "hot pink", "blush", "fuchsia", "magenta"}:
        return _profile_or_default("pink_charm", profiles, default_profile)

    if vehicle_type in {"sport", "sports", "sportcar", "sports_car", "coupe", "performance"}:
        return _profile_or_default("sporty", profiles, default_profile)

    if vehicle_type in {"family", "family_car", "minivan", "mpv", "wagon", "crossover"}:
        return _profile_or_default("family", profiles, default_profile)

    if vehicle_type in {"suv", "truck", "pickup", "offroad", "off-road", "utility"}:
        return _profile_or_default("rugged", profiles, default_profile)

    if age_group in {"old", "classic", "vintage", "older"}:
        return _profile_or_default("classic", profiles, default_profile)

    if age_group in {"new", "fresh", "modern"}:
        return _profile_or_default("fresh", profiles, default_profile)

    if age_years is not None:
        if age_years >= 15:
            return _profile_or_default("classic", profiles, default_profile)
        if age_years <= 3:
            return _profile_or_default("fresh", profiles, default_profile)

    brand = str(vehicle.get("brand") or "").lower()
    model = str(vehicle.get("model") or "").lower()
    hints = f"{brand} {model}"

    if any(word in hints for word in ("porsche", "mustang", "camaro", "m3", "amg", "rs", "gt")):
        return "sporty" if "sporty" in profiles else default_profile

    if any(word in hints for word in ("range rover", "lexus", "mercedes", "bmw", "audi", "genesis")):
        return "formal" if "formal" in profiles else default_profile

    if any(word in hints for word in ("jeep", "land cruiser", "rav4", "tacoma", "hilux", "patrol", "wrangler")):
        return "rugged" if "rugged" in profiles else default_profile

    if any(word in hints for word in ("mini", "fiat", "smart", "swift", "yaris", "fit")):
        return "playful" if "playful" in profiles else default_profile

    return default_profile


def build_personality_instructions(context: dict[str, Any]) -> tuple[str, dict[str, Any]]:
    profiles_config = load_personality_profiles()
    profile_id = infer_personality_profile(context, profiles_config)
    profile = profiles_config["profiles"][profile_id]

    instructions = {
        "selected_profile": profile_id,
        "profile_name": profile["name"],
        "vehicle_voice": profile["vehicle_voice"],
        "description": profile["description"],
        "tone": profile["tone"],
        "style_rules": profile["style_rules"],
        "global_rules": profiles_config["global_rules"],
        "avoid": profile["avoid"],
        "sample_openers": profile["sample_openers"],
    }

    text = (
        "VEHICLE PERSONALITY\n"
        f"selected_profile: {profile_id}\n"
        f"profile_name: {profile['name']}\n"
        f"vehicle_voice: {profile['vehicle_voice']}\n\n"
        "global_rules:\n"
        + "\n".join(f"- {rule}" for rule in profiles_config["global_rules"])
        + "\n\nstyle_rules:\n"
        + "\n".join(f"- {rule}" for rule in profile["style_rules"])
        + "\n\navoid:\n"
        + "\n".join(f"- {rule}" for rule in profile["avoid"])
    )

    return text, instructions
