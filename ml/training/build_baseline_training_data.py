#!/usr/bin/env python3

import argparse
import json
import re
from pathlib import Path

import pandas as pd


ML_ROOT = Path(__file__).resolve().parents[1]
DEMO_DATA_DIR = ML_ROOT / "demo_data"
OUTPUT_DIR = ML_ROOT / "training" / "baseline"
TARGET_COLUMN = "maintenance_needed"
VALIDATION_RATIO = 0.2
RANDOM_STATE = 42

FEATURE_SCHEMA = {
    "schema_version": "baseline-training-features-v0.1",
    "entity": "vehicle",
    "target": {
        "name": TARGET_COLUMN,
        "type": "binary_integer",
        "values": {
            "0": "No immediate maintenance need in the source maintenance baseline.",
            "1": "Maintenance needed in the source maintenance baseline."
        },
        "source": "Parsed from the derived maintenance baseline event description.",
    },
    "features": [
        {
            "name": "vehicle_age_years",
            "type": "integer",
            "source": "vehicle profile",
            "description": "Dataset reference year minus vehicle production year.",
        },
        {
            "name": "mileage_km",
            "type": "integer",
            "source": "vehicle profile",
            "description": "Current vehicle odometer reading.",
        },
        {
            "name": "mileage_bucket",
            "type": "categorical",
            "source": "mileage",
            "description": "Mileage grouped into low, medium, high, or very_high.",
        },
        {
            "name": "brand",
            "type": "categorical",
            "source": "vehicle profile",
            "description": "Vehicle brand.",
        },
        {
            "name": "model",
            "type": "categorical",
            "source": "vehicle profile",
            "description": "Vehicle model.",
        },
        {
            "name": "body_class",
            "type": "categorical",
            "source": "vehicle profile",
            "description": "Vehicle body class from decoded profile data.",
        },
        {
            "name": "fuel_type",
            "type": "categorical",
            "source": "vehicle profile",
            "description": "Fuel type used by the vehicle.",
        },
        {
            "name": "transmission",
            "type": "categorical",
            "source": "vehicle profile",
            "description": "Vehicle transmission description.",
        },
        {
            "name": "maintenance_event_count",
            "type": "integer",
            "source": "maintenance history",
            "description": "Number of maintenance/service events for the vehicle.",
        },
        {
            "name": "service_count_source",
            "type": "integer",
            "source": "maintenance history",
            "description": "Service count parsed from the source maintenance baseline description.",
        },
        {
            "name": "maintenance_history_quality",
            "type": "categorical",
            "source": "maintenance history",
            "description": "Source maintenance history quality label.",
        },
        {
            "name": "maintenance_history_score",
            "type": "integer",
            "source": "maintenance history",
            "description": "Ordinal encoding of maintenance history quality: poor=0, average=1, good=2.",
        },
        {
            "name": "km_since_last_maintenance",
            "type": "integer",
            "source": "maintenance history",
            "description": "Current mileage minus latest non-recall maintenance event mileage.",
        },
        {
            "name": "repair_event_count",
            "type": "integer",
            "source": "repair history",
            "description": "Number of repair events for the vehicle.",
        },
        {
            "name": "km_since_last_repair",
            "type": "integer",
            "source": "repair history",
            "description": "Current mileage minus latest repair event mileage.",
        },
        {
            "name": "repair_cost_total",
            "type": "number",
            "source": "repair history",
            "description": "Total cost of repair events in the demo data.",
        },
        {
            "name": "refuel_event_count",
            "type": "integer",
            "source": "refueling history",
            "description": "Number of refuel events for the vehicle.",
        },
        {
            "name": "km_since_last_refuel",
            "type": "integer",
            "source": "refueling history",
            "description": "Current mileage minus latest refuel event mileage.",
        },
        {
            "name": "fuel_efficiency_km_per_liter",
            "type": "number",
            "source": "refueling history",
            "description": "Fuel efficiency parsed from derived refuel event description.",
        },
        {
            "name": "tracked_part_count",
            "type": "integer",
            "source": "parts state",
            "description": "Number of tracked parts for the vehicle.",
        },
        {
            "name": "avg_part_age_km",
            "type": "number",
            "source": "parts state",
            "description": "Average current mileage minus installed-at mileage for tracked parts.",
        },
        {
            "name": "avg_km_since_part_service",
            "type": "number",
            "source": "parts state",
            "description": "Average current mileage minus last service mileage for tracked parts.",
        },
    ],
    "split": {
        "method": "deterministic stratified split by target",
        "validation_ratio": VALIDATION_RATIO,
        "random_state": RANDOM_STATE,
    },
}

EXPANDED_FEATURE_SCHEMA = {
    "schema_version": "baseline-training-features-v0.2",
    "entity": "vehicle_part",
    "target": FEATURE_SCHEMA["target"],
    "base_schema": "baseline-training-features-v0.1",
    "features": [
        *FEATURE_SCHEMA["features"],
        {
            "name": "part_name",
            "type": "categorical",
            "source": "parts state",
            "description": "Tracked part display name.",
        },
        {
            "name": "part_category",
            "type": "categorical",
            "source": "parts state",
            "description": "Tracked part category from demo parts data.",
        },
        {
            "name": "part_source",
            "type": "categorical",
            "source": "parts state",
            "description": "Source system that produced the part record.",
        },
        {
            "name": "part_age_km",
            "type": "integer",
            "source": "parts state",
            "description": "Current vehicle mileage minus part installation mileage, or -1 when unknown.",
        },
        {
            "name": "part_age_known",
            "type": "integer",
            "source": "parts state",
            "description": "1 when part installation mileage is known, otherwise 0.",
        },
        {
            "name": "km_since_part_service",
            "type": "integer",
            "source": "parts state",
            "description": "Current vehicle mileage minus part last service mileage, or -1 when unknown.",
        },
        {
            "name": "km_since_part_service_known",
            "type": "integer",
            "source": "parts state",
            "description": "1 when part last service mileage is known, otherwise 0.",
        },
        {
            "name": "is_core_maintenance_part",
            "type": "integer",
            "source": "parts state",
            "description": "1 when the part is one of engine oil, brake pads, or timing belt.",
        },
        {
            "name": "matching_repair_event_count",
            "type": "integer",
            "source": "repair history",
            "description": "Count of repair events linked to the part by source id or text match.",
        },
        {
            "name": "matching_repair_cost_total",
            "type": "number",
            "source": "repair history",
            "description": "Total repair cost for events linked to this part.",
        },
    ],
    "split": {
        "method": "vehicle-grouped split inherited from the vehicle-level dataset",
        "validation_ratio": VALIDATION_RATIO,
        "random_state": RANDOM_STATE,
    },
}


def load_demo_data(data_dir):
    data_dir = Path(data_dir)
    return {
        "vehicles": pd.read_csv(data_dir / "vehicles.csv"),
        "events": pd.read_csv(data_dir / "vehicle_events.csv"),
        "parts": pd.read_csv(data_dir / "parts.csv"),
    }


def normalize_event_type(value):
    if value == "service":
        return "maintenance"
    return value


def mileage_bucket(mileage_km):
    if mileage_km < 60000:
        return "low"
    if mileage_km < 100000:
        return "medium"
    if mileage_km < 150000:
        return "high"
    return "very_high"


def parse_int(pattern, text):
    match = re.search(pattern, str(text), flags=re.IGNORECASE)
    if not match:
        return None
    return int(match.group(1))


def parse_float(pattern, text):
    match = re.search(pattern, str(text), flags=re.IGNORECASE)
    if not match:
        return None
    return float(match.group(1))


def parse_maintenance_quality(text):
    match = re.search(r"maintenance history:\s*([^;]+)", str(text), flags=re.IGNORECASE)
    if not match:
        return "unknown"
    return match.group(1).strip().lower()


def maintenance_quality_score(quality):
    return {
        "poor": 0,
        "average": 1,
        "good": 2,
    }.get(quality, -1)


def normalized_token(value):
    return re.sub(r"[^a-z0-9]+", " ", str(value or "").lower()).strip()


def latest_mileage(events):
    if events.empty:
        return None
    return int(events["mileage_km"].max())


def safe_distance(current_mileage, historical_mileage):
    if historical_mileage is None or pd.isna(historical_mileage):
        return None
    return max(0, int(current_mileage) - int(historical_mileage))


def model_distance(current_mileage, historical_mileage):
    if historical_mileage is None or pd.isna(historical_mileage):
        return -1, 0
    return max(0, int(current_mileage) - int(historical_mileage)), 1


def non_recall_maintenance_events(events):
    maintenance = events[events["normalized_type"] == "maintenance"]
    return maintenance[~maintenance["title"].str.startswith("Recall:", na=False)]


def baseline_event(events):
    candidates = events[
        (events["normalized_type"] == "maintenance")
        & events["title"].eq("Recorded maintenance baseline")
    ]
    if candidates.empty:
        return None
    return candidates.sort_values(["event_date", "id"]).iloc[-1]


def build_feature_rows(vehicles_df, events_df, parts_df):
    rows = []
    events_df = events_df.copy()
    events_df["normalized_type"] = events_df["type"].map(normalize_event_type)
    reference_year = int(pd.to_datetime(events_df["event_date"]).dt.year.max())

    for _, vehicle in vehicles_df.sort_values("id").iterrows():
        vehicle_id = int(vehicle["id"])
        current_mileage = int(vehicle["mileage_km"])
        vehicle_events = events_df[events_df["vehicle_id"] == vehicle_id].copy()
        vehicle_parts = parts_df[parts_df["vehicle_id"] == vehicle_id].copy()
        baseline = baseline_event(vehicle_events)

        if baseline is None:
            raise ValueError(f"Vehicle {vehicle_id} has no maintenance baseline event")

        baseline_description = str(baseline["description"])
        target = parse_int(r"maintenance needed:\s*([01])", baseline_description)
        if target is None:
            raise ValueError(f"Vehicle {vehicle_id} has no maintenance target")

        maintenance_events = non_recall_maintenance_events(vehicle_events)
        repair_events = vehicle_events[vehicle_events["normalized_type"] == "repair"]
        refuel_events = vehicle_events[vehicle_events["normalized_type"] == "refuel"]

        latest_maintenance_mileage = latest_mileage(maintenance_events)
        latest_repair_mileage = latest_mileage(repair_events)
        latest_refuel_mileage = latest_mileage(refuel_events)

        part_age_km = current_mileage - pd.to_numeric(
            vehicle_parts["installed_at_mileage_km"],
            errors="coerce",
        )
        part_service_age_km = current_mileage - pd.to_numeric(
            vehicle_parts["last_service_mileage_km"],
            errors="coerce",
        )

        quality = parse_maintenance_quality(baseline_description)

        rows.append({
            "vehicle_id": vehicle_id,
            TARGET_COLUMN: target,
            "vehicle_age_years": reference_year - int(vehicle["year"]),
            "mileage_km": current_mileage,
            "mileage_bucket": mileage_bucket(current_mileage),
            "brand": vehicle["brand"],
            "model": vehicle["model"],
            "body_class": vehicle.get("body_class"),
            "fuel_type": vehicle.get("fuel_type"),
            "transmission": vehicle.get("transmission"),
            "maintenance_event_count": int(len(maintenance_events)),
            "service_count_source": parse_int(r"service count:\s*(\d+)", baseline_description),
            "maintenance_history_quality": quality,
            "maintenance_history_score": maintenance_quality_score(quality),
            "km_since_last_maintenance": safe_distance(current_mileage, latest_maintenance_mileage),
            "repair_event_count": int(len(repair_events)),
            "km_since_last_repair": safe_distance(current_mileage, latest_repair_mileage),
            "repair_cost_total": float(repair_events["cost"].fillna(0).sum()),
            "refuel_event_count": int(len(refuel_events)),
            "km_since_last_refuel": safe_distance(current_mileage, latest_refuel_mileage),
            "fuel_efficiency_km_per_liter": parse_float(
                r"fuel efficiency is\s*([0-9.]+)\s*km/l",
                " ".join(refuel_events["description"].dropna().astype(str)),
            ),
            "tracked_part_count": int(len(vehicle_parts)),
            "avg_part_age_km": round(float(part_age_km.dropna().mean()), 2),
            "avg_km_since_part_service": round(float(part_service_age_km.dropna().mean()), 2),
        })

    return pd.DataFrame(rows)


def matching_part_repair_events(part, repair_events):
    if repair_events.empty:
        return repair_events

    part_source_id = str(part.get("source_id", "")).strip()
    if part_source_id:
        source_matches = repair_events[
            repair_events["source_id"].fillna("").astype(str).str.strip().eq(part_source_id)
        ]
        if not source_matches.empty:
            return source_matches

    part_name = normalized_token(part.get("name"))
    if not part_name:
        return repair_events.iloc[0:0]

    text = (
        repair_events["title"].fillna("")
        + " "
        + repair_events["description"].fillna("")
    ).map(normalized_token)

    first_token = part_name.split()[0]
    return repair_events[text.str.contains(first_token, regex=False)]


def build_expanded_feature_rows(vehicle_dataset, events_df, parts_df):
    rows = []
    events_df = events_df.copy()
    events_df["normalized_type"] = events_df["type"].map(normalize_event_type)

    for _, vehicle_features in vehicle_dataset.sort_values("vehicle_id").iterrows():
        vehicle_id = int(vehicle_features["vehicle_id"])
        current_mileage = int(vehicle_features["mileage_km"])
        vehicle_events = events_df[events_df["vehicle_id"] == vehicle_id].copy()
        repair_events = vehicle_events[vehicle_events["normalized_type"] == "repair"]
        vehicle_parts = parts_df[parts_df["vehicle_id"] == vehicle_id].copy()

        for _, part in vehicle_parts.sort_values("id").iterrows():
            installed_at = pd.to_numeric(part.get("installed_at_mileage_km"), errors="coerce")
            last_service = pd.to_numeric(part.get("last_service_mileage_km"), errors="coerce")
            part_age_km, part_age_known = model_distance(current_mileage, installed_at)
            km_since_part_service, km_since_part_service_known = model_distance(
                current_mileage,
                last_service,
            )
            matched_repairs = matching_part_repair_events(part, repair_events)
            part_name = str(part["name"])

            row = vehicle_features.to_dict()
            row.update({
                "part_id": int(part["id"]),
                "part_name": part_name,
                "part_category": part.get("category"),
                "part_source": part.get("source"),
                "part_age_km": part_age_km,
                "part_age_known": part_age_known,
                "km_since_part_service": km_since_part_service,
                "km_since_part_service_known": km_since_part_service_known,
                "is_core_maintenance_part": int(part_name in {"Engine oil", "Brake pads", "Timing belt"}),
                "matching_repair_event_count": int(len(matched_repairs)),
                "matching_repair_cost_total": float(matched_repairs["cost"].fillna(0).sum()),
            })
            rows.append(row)

    return pd.DataFrame(rows)


def split_train_validation(dataset):
    validation_parts = []
    for _, group in dataset.groupby(TARGET_COLUMN, group_keys=False):
        validation_size = max(1, round(len(group) * VALIDATION_RATIO))
        validation_parts.append(group.sample(n=validation_size, random_state=RANDOM_STATE))

    validation = pd.concat(validation_parts).sort_values("vehicle_id")
    train = dataset.drop(validation.index).sort_values("vehicle_id")
    return train, validation


def write_outputs(dataset, train, validation, output_dir):
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    dataset.to_csv(output_dir / "baseline_training_dataset.csv", index=False)
    train.to_csv(output_dir / "train.csv", index=False)
    validation.to_csv(output_dir / "validation.csv", index=False)
    with open(output_dir / "feature_schema.json", "w", encoding="utf-8") as schema_file:
        json.dump(FEATURE_SCHEMA, schema_file, indent=2)
        schema_file.write("\n")


def split_expanded_by_vehicle(expanded_dataset, train, validation):
    train_vehicle_ids = set(train["vehicle_id"])
    validation_vehicle_ids = set(validation["vehicle_id"])
    expanded_train = expanded_dataset[expanded_dataset["vehicle_id"].isin(train_vehicle_ids)]
    expanded_validation = expanded_dataset[expanded_dataset["vehicle_id"].isin(validation_vehicle_ids)]
    return (
        expanded_train.sort_values(["vehicle_id", "part_id"]),
        expanded_validation.sort_values(["vehicle_id", "part_id"]),
    )


def write_expanded_outputs(dataset, train, validation, output_dir):
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    dataset.to_csv(output_dir / "expanded_training_dataset.csv", index=False)
    train.to_csv(output_dir / "expanded_train.csv", index=False)
    validation.to_csv(output_dir / "expanded_validation.csv", index=False)
    with open(output_dir / "expanded_feature_schema.json", "w", encoding="utf-8") as schema_file:
        json.dump(EXPANDED_FEATURE_SCHEMA, schema_file, indent=2)
        schema_file.write("\n")


def main():
    parser = argparse.ArgumentParser(description="Build baseline training data from demo CSV files.")
    parser.add_argument("--data-dir", default=DEMO_DATA_DIR, type=Path)
    parser.add_argument("--output-dir", default=OUTPUT_DIR, type=Path)
    args = parser.parse_args()

    data = load_demo_data(args.data_dir)
    dataset = build_feature_rows(data["vehicles"], data["events"], data["parts"])
    train, validation = split_train_validation(dataset)
    expanded_dataset = build_expanded_feature_rows(dataset, data["events"], data["parts"])
    expanded_train, expanded_validation = split_expanded_by_vehicle(
        expanded_dataset,
        train,
        validation,
    )
    write_outputs(dataset, train, validation, args.output_dir)
    write_expanded_outputs(
        expanded_dataset,
        expanded_train,
        expanded_validation,
        args.output_dir,
    )

    print(f"dataset_rows={len(dataset)}")
    print(f"train_rows={len(train)}")
    print(f"validation_rows={len(validation)}")
    print(f"features={len(FEATURE_SCHEMA['features'])}")
    print(f"target_distribution={dataset[TARGET_COLUMN].value_counts().sort_index().to_dict()}")
    print(f"expanded_dataset_rows={len(expanded_dataset)}")
    print(f"expanded_train_rows={len(expanded_train)}")
    print(f"expanded_validation_rows={len(expanded_validation)}")
    print(f"expanded_features={len(EXPANDED_FEATURE_SCHEMA['features'])}")
    print(
        "expanded_target_distribution="
        f"{expanded_dataset[TARGET_COLUMN].value_counts().sort_index().to_dict()}"
    )


if __name__ == "__main__":
    main()
