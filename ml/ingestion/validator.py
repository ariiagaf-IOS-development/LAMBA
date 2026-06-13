EVENT_TYPES = {"trip", "refuel", "repair", "service"}

# parts that are currently used in mock responses
MOCK_RESPONSE_PARTS = {
    "Engine oil",
    "Brake pads",
    "Timing belt",
}

def validate_vehicles(vehicles_df):
    errors = []
    required = ["id", "brand", "model", "year", "mileage_km"]
    for column in required:
        if column not in vehicles_df.columns:
            errors.append(f"vehicles.csv: missing column {column}")
    if errors:
        return errors

    if vehicles_df["id"].isnull().any():
        errors.append("vehicles.csv: vehicle id cannot be empty")

    if vehicles_df["mileage_km"].isnull().any():
        errors.append("vehicles.csv: mileage_km cannot be empty")

    invalid_year = (vehicles_df["year"] < 1970) | (vehicles_df["year"] > 2035)
    if invalid_year.any():
        errors.append("vehicles.csv: year is not real")

    return errors

def validate_events(events_df):
    errors = []
    required = ["vehicle_id", "type", "mileage_km", "cost"]
    for column in required:
        if column not in events_df.columns:
            errors.append(f"vehicle_events.csv: missing column {column}")
    if errors:
        return errors

    if events_df["vehicle_id"].isnull().any():
        errors.append("vehicle_events.csv: vehicle_id cannot be empty")

    if events_df["mileage_km"].isnull().any():
        errors.append("vehicle_events.csv: mileage_km cannot be empty")

    invalid_type = ~events_df["type"].isin(EVENT_TYPES)
    if invalid_type.any():
        errors.append("vehicle_events.csv: type must be trip/refuel/repair/service")

    if (events_df["cost"] < 0).any():
        errors.append("vehicle_events.csv: cost cannot be negative")

    return errors

def validate_parts(parts_df):
    errors = []
    required = ["vehicle_id", "name"]
    for column in required:
        if column not in parts_df.columns:
            errors.append(f"parts.csv: missing column {column}")
    if errors:
        return errors

    if parts_df["vehicle_id"].isnull().any():
        errors.append("parts.csv: vehicle_id cannot be empty")

    if parts_df["name"].isnull().any():
        errors.append("parts.csv: part name cannot be empty")

    existing_parts = set(parts_df["name"].dropna().unique())
    missing_recommended = MOCK_RESPONSE_PARTS - existing_parts

    if missing_recommended:
        errors.append(
            "parts.csv: recommended parts for mock responses are missing: "
            + ", ".join(sorted(missing_recommended))
        )

    return errors

def validate_relations(vehicles_df, events_df, parts_df):
    errors = []
    vehicle_ids = set(vehicles_df["id"])
    
    unknown_event_ids = set(events_df["vehicle_id"]) - vehicle_ids
    if unknown_event_ids:
        errors.append(f"vehicle_events.csv: unknown vehicle_id values: {unknown_event_ids}")

    unknown_part_ids = set(parts_df["vehicle_id"]) - vehicle_ids
    if unknown_part_ids:
        errors.append(f"parts.csv: unknown vehicle_id values: {unknown_part_ids}")

    return errors

def validate_all(vehicles_df, events_df, parts_df):
    errors = []
    errors.extend(validate_vehicles(vehicles_df))
    errors.extend(validate_events(events_df))
    errors.extend(validate_parts(parts_df))
    errors.extend(validate_relations(vehicles_df, events_df, parts_df))
    return errors