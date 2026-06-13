import json

from loader import load_all
from validator import validate_all

# replace pandas NaN with None so that the json contains null
def clean_record(record):
    cleaned = {}
    for key, value in record.items():
        if value != value:
            cleaned[key] = None
        else:
            cleaned[key] = value
    return cleaned

def build_ml_request(vehicle_id, vehicles_df, events_df, parts_df):
    vehicle_row = vehicles_df[vehicles_df["id"] == vehicle_id]

    if vehicle_row.empty:
        raise ValueError(f"Vehicle with id={vehicle_id} not found")

    vehicle = clean_record(vehicle_row.iloc[0].to_dict())
    
    events = events_df[events_df["vehicle_id"] == vehicle_id]
    parts = parts_df[parts_df["vehicle_id"] == vehicle_id]
    event_records = [
        clean_record(row)
        for row in events.to_dict(orient="records")
    ]
    part_records = [
        clean_record(row)
        for row in parts.to_dict(orient="records")
    ]

    return {
        "vehicle": vehicle,
        "events": event_records,
        "parts": part_records,
    }


def build_all_requests(vehicles_df, events_df, parts_df):
    requests = []
    for vehicle_id in vehicles_df["id"]:
        request = build_ml_request(
            vehicle_id,
            vehicles_df,
            events_df,
            parts_df,
        )
        requests.append(request)
    return requests


if __name__ == "__main__":
    data = load_all()
    errors = validate_all(
        data["vehicles"],
        data["events"],
        data["parts"],
    )
    if errors:
        print("Validation errors:")
        for error in errors:
            print("-", error)
        raise SystemExit(1)
    first_vehicle_id = data["vehicles"].iloc[0]["id"]
    request = build_ml_request(
        first_vehicle_id,
        data["vehicles"],
        data["events"],
        data["parts"],
    )
    print(json.dumps(request, indent=2, ensure_ascii=False, default=str))