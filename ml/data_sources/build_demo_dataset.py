#!/usr/bin/env python3

import argparse
import csv
import io
import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone
from pathlib import Path


CAR_API = "https://carapi.app/api"
VPIC_API = "https://vpic.nhtsa.dot.gov/api/vehicles"
NHTSA_API = "https://api.nhtsa.gov"
KAGGLE_DOWNLOAD = (
    "https://www.kaggle.com/api/v1/datasets/download/"
    "chavindudulaj/vehicle-maintenance-data"
)
DVSA_API = "https://history.mot.api.gov.uk"

VEHICLE_PROFILES = [
    ("Toyota", "Camry", 2018),
    ("Toyota", "Corolla", 2019),
    ("Toyota", "RAV4", 2020),
    ("Honda", "Civic", 2020),
    ("Honda", "Accord", 2019),
    ("Honda", "CR-V", 2020),
    ("Ford", "Escape", 2019),
    ("Ford", "Explorer", 2020),
    ("Ford", "Mustang", 2019),
    ("Chevrolet", "Equinox", 2020),
    ("Chevrolet", "Malibu", 2019),
    ("Chevrolet", "Traverse", 2020),
    ("Nissan", "Rogue", 2019),
    ("Nissan", "Altima", 2020),
    ("Nissan", "Sentra", 2019),
    ("Hyundai", "Sonata", 2018),
    ("Hyundai", "Elantra", 2020),
    ("Hyundai", "Tucson", 2019),
    ("Kia", "Sportage", 2020),
    ("Kia", "Optima", 2019),
    ("Kia", "Sorento", 2020),
    ("Volkswagen", "Jetta", 2019),
    ("Volkswagen", "Tiguan", 2020),
    ("Volkswagen", "Passat", 2018),
    ("Mazda", "CX-5", 2018),
    ("Mazda", "CX-9", 2019),
    ("Mazda", "CX-3", 2020),
    ("Subaru", "Outback", 2020),
    ("Subaru", "Forester", 2019),
    ("Subaru", "Impreza", 2020),
]

VEHICLE_FIELDS = [
    "id",
    "brand",
    "model",
    "year",
    "vin",
    "mileage_km",
    "body_class",
    "engine",
    "fuel_type",
    "manufacturer",
    "trim",
    "transmission",
    "source",
]
EVENT_FIELDS = [
    "id",
    "vehicle_id",
    "type",
    "title",
    "description",
    "mileage_km",
    "cost",
    "event_date",
    "source",
    "source_id",
]
PART_FIELDS = [
    "id",
    "vehicle_id",
    "name",
    "category",
    "installed_at_mileage_km",
    "last_service_mileage_km",
    "source",
    "source_id",
]


def request_bytes(url, headers=None, data=None, timeout=30, attempts=3):
    request_headers = {
        "Accept": "application/json",
        "User-Agent": "LAMBA-demo-dataset-builder/1.0",
    }
    request_headers.update(headers or {})
    request = urllib.request.Request(url, headers=request_headers, data=data)

    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            if error.code == 400:
                return error.read()
            if attempt == attempts:
                raise
            time.sleep(attempt)
        except (urllib.error.URLError, TimeoutError):
            if attempt == attempts:
                raise
            time.sleep(attempt)


def request_json(url, headers=None, data=None, timeout=30):
    return json.loads(request_bytes(url, headers, data, timeout).decode("utf-8"))


def api_url(base, path, **query):
    encoded_path = "/".join(urllib.parse.quote(str(part), safe="-") for part in path)
    return f"{base}/{encoded_path}?{urllib.parse.urlencode(query)}"


def compact_text(value, limit=500):
    text = " ".join(str(value or "").split())
    return text[:limit]


def parse_date(value, formats):
    for date_format in formats:
        try:
            return datetime.strptime(value, date_format).replace(tzinfo=timezone.utc)
        except (TypeError, ValueError):
            continue
    return None


def iso_date(value):
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_failure_mileage_km(summary):
    compact_match = re.search(r"(\d+(?:\.\d+)?)k\s*miles", str(summary or "").lower())
    if compact_match:
        miles = round(float(compact_match.group(1)) * 1000)
        return round(miles * 1.60934)

    patterns = [
        r"approximate failure mileage was\s+([\d,]+)",
        r"failure mileage was\s+([\d,]+)",
        r"approximately\s+([\d,]+)\s+miles",
        r"([\d,]+)\s+miles",
    ]
    lowered = str(summary or "").lower()
    for pattern in patterns:
        match = re.search(pattern, lowered)
        if match:
            miles = int(match.group(1).replace(",", ""))
            return round(miles * 1.60934)
    return None


def load_kaggle_rows(timeout, count):
    archive = request_bytes(KAGGLE_DOWNLOAD, timeout=timeout)
    with zipfile.ZipFile(io.BytesIO(archive)) as zipped:
        csv_names = [name for name in zipped.namelist() if name.endswith(".csv")]
        if not csv_names:
            raise RuntimeError("Kaggle archive does not contain a CSV file")
        with zipped.open(csv_names[0]) as source:
            reader = csv.DictReader(io.TextIOWrapper(source, encoding="utf-8-sig"))
            rows = [row for row in reader if row["Vehicle_Model"] in {"Car", "SUV"}]

    if len(rows) < count:
        raise RuntimeError("Kaggle dataset has too few Car/SUV records")
    return rows[:count]


def fetch_carapi(make, model, year, timeout):
    trims_url = api_url(
        CAR_API,
        ["trims", "v2"],
        year=year,
        make=make,
        model=model,
        limit=1,
    )
    trims = request_json(trims_url, timeout=timeout).get("data", [])
    if not trims:
        raise RuntimeError(f"CarAPI has no trim for {year} {make} {model}")
    return request_json(f"{CAR_API}/trims/v2/{trims[0]['id']}", timeout=timeout)


def fetch_vpic_model(make, model, year, timeout):
    url = api_url(
        VPIC_API,
        ["GetModelsForMakeYear", "make", make, "modelyear", year],
        format="json",
    )
    results = request_json(url, timeout=timeout).get("Results", [])
    target = model.lower().replace("-", "")
    for result in results:
        candidate = str(result.get("Model_Name", "")).lower().replace("-", "")
        if candidate == target:
            return result
    return {}


def fetch_complaints(make, model, year, timeout):
    url = api_url(
        NHTSA_API,
        ["complaints", "complaintsByVehicle"],
        make=make,
        model=model,
        modelYear=year,
    )
    return request_json(url, timeout=timeout).get("results", [])


def fetch_recalls(make, model, year, timeout):
    url = api_url(
        NHTSA_API,
        ["recalls", "recallsByVehicle"],
        make=make,
        model=model,
        modelYear=year,
    )
    return request_json(url, timeout=timeout).get("results", [])


def decode_vin(vin, year, timeout):
    if not vin:
        return {}
    url = api_url(
        VPIC_API,
        ["DecodeVinValues", vin],
        format="json",
        modelyear=year,
    )
    results = request_json(url, timeout=timeout).get("Results", [])
    return results[0] if results else {}


def carapi_specs(trim):
    body = (trim.get("bodies") or [{}])[0]
    engine = (trim.get("engines") or [{}])[0]
    transmission = (trim.get("transmissions") or [{}])[0]
    engine_parts = [
        engine.get("engine_type"),
        f"{engine.get('size')}L" if engine.get("size") else None,
        engine.get("cylinders"),
        f"{engine.get('horsepower_hp')} hp" if engine.get("horsepower_hp") else None,
    ]
    return {
        "body_class": body.get("type", ""),
        "engine": " ".join(str(part) for part in engine_parts if part),
        "fuel_type": engine.get("fuel_type", ""),
        "trim": trim.get("submodel") or trim.get("trim") or "",
        "transmission": transmission.get("description", ""),
    }


def fetch_vehicle_bundle(vehicle_id, profile, kaggle_row, timeout):
    make, model, year = profile
    trim = fetch_carapi(make, model, year, timeout)
    complaints = fetch_complaints(make, model, year, timeout)
    recalls = fetch_recalls(make, model, year, timeout)
    vpic_model = fetch_vpic_model(make, model, year, timeout)

    complaint = complaints[0] if complaints else {}
    recall = recalls[0] if recalls else {}
    vin = complaint.get("vin", "")
    decoded_vin = decode_vin(vin, year, timeout)

    baseline_mileage = max(
        int(float(kaggle_row["Mileage"])),
        int(float(kaggle_row["Odometer_Reading"])),
    )
    complaint_mileage = parse_failure_mileage_km(complaint.get("summary")) or 0
    mileage_km = max(baseline_mileage, complaint_mileage)
    specs = carapi_specs(trim)

    manufacturer = (
        decoded_vin.get("Manufacturer")
        or complaint.get("manufacturer")
        or recall.get("Manufacturer")
        or make
    )
    vehicle = {
        "id": vehicle_id,
        "brand": make,
        "model": model,
        "year": year,
        "vin": vin,
        "mileage_km": mileage_km,
        "body_class": decoded_vin.get("BodyClass") or specs["body_class"],
        "engine": specs["engine"],
        "fuel_type": decoded_vin.get("FuelTypePrimary") or specs["fuel_type"],
        "manufacturer": manufacturer,
        "trim": specs["trim"],
        "transmission": specs["transmission"],
        "source": "CarAPI + NHTSA vPIC + NHTSA complaints + Kaggle",
    }

    return {
        "vehicle": vehicle,
        "trim": trim,
        "vpic_model": vpic_model,
        "complaints": complaints,
        "recalls": recalls,
        "kaggle": kaggle_row,
    }


def load_dvsa_vins(path):
    if not path:
        return {}
    with Path(path).open(newline="", encoding="utf-8-sig") as source:
        return {
            int(row["vehicle_id"]): row["vin"].strip()
            for row in csv.DictReader(source)
            if row.get("vehicle_id") and row.get("vin")
        }


def fetch_dvsa_records(vins, timeout):
    required = {
        "DVSA_CLIENT_ID": os.getenv("DVSA_CLIENT_ID"),
        "DVSA_CLIENT_SECRET": os.getenv("DVSA_CLIENT_SECRET"),
        "DVSA_TOKEN_URL": os.getenv("DVSA_TOKEN_URL"),
        "DVSA_API_KEY": os.getenv("DVSA_API_KEY"),
    }
    if not vins:
        return {}
    missing = [name for name, value in required.items() if not value]
    if missing:
        raise RuntimeError("DVSA VIN file supplied but credentials are missing: " + ", ".join(missing))

    token_data = urllib.parse.urlencode(
        {
            "grant_type": "client_credentials",
            "client_id": required["DVSA_CLIENT_ID"],
            "client_secret": required["DVSA_CLIENT_SECRET"],
            "scope": os.getenv("DVSA_SCOPE", "https://tapi.dvsa.gov.uk/.default"),
        }
    ).encode("ascii")
    token = request_json(
        required["DVSA_TOKEN_URL"],
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        data=token_data,
        timeout=timeout,
    )["access_token"]
    headers = {
        "Authorization": f"Bearer {token}",
        "X-API-Key": required["DVSA_API_KEY"],
    }
    records = {}
    for vehicle_id, vin in vins.items():
        url = f"{DVSA_API}/v1/trade/vehicles/vin/{urllib.parse.quote(vin)}"
        records[vehicle_id] = request_json(url, headers=headers, timeout=timeout)
    return records


def latest_mot_event(record, vehicle_id, fallback_mileage):
    tests = record.get("motTests") or record.get("motTest") or []
    if not tests:
        return None
    test = tests[0]
    completed = test.get("completedDate") or test.get("testDate")
    event_date = parse_date(completed, ["%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%d"])
    mileage = test.get("odometerValue") or test.get("odometerReading") or fallback_mileage
    defects = test.get("defects") or test.get("rfrAndComments") or []
    return {
        "vehicle_id": vehicle_id,
        "type": "service",
        "title": f"MOT test: {test.get('testResult', 'recorded')}",
        "description": compact_text(json.dumps(defects, ensure_ascii=False)),
        "mileage_km": int(float(mileage)),
        "cost": "0.00",
        "event_date": iso_date(event_date or datetime.now(timezone.utc)),
        "source": "DVSA MOT History API",
        "source_id": test.get("motTestNumber", ""),
    }


def build_events(bundle, dvsa_record=None):
    vehicle = bundle["vehicle"]
    vehicle_id = vehicle["id"]
    kaggle = bundle["kaggle"]
    complaints = bundle["complaints"]
    recalls = bundle["recalls"]
    current_mileage = vehicle["mileage_km"]
    baseline_mileage = max(
        int(float(kaggle["Mileage"])),
        int(float(kaggle["Odometer_Reading"])),
    )
    service_date = parse_date(kaggle["Last_Service_Date"], ["%Y-%m-%d"])
    service_date = service_date or datetime(2023, 1, 1, tzinfo=timezone.utc)

    events = [
        {
            "vehicle_id": vehicle_id,
            "type": "trip",
            "title": "Mileage baseline trip",
            "description": "Derived training event from the Kaggle odometer record.",
            "mileage_km": max(0, baseline_mileage - 1000),
            "cost": "0.00",
            "event_date": iso_date(service_date - timedelta(days=60)),
            "source": "Kaggle vehicle-maintenance-data (derived)",
            "source_id": vehicle_id,
        },
        {
            "vehicle_id": vehicle_id,
            "type": "refuel",
            "title": f"{vehicle['fuel_type']} refuel baseline",
            "description": (
                "Derived training event; source fuel efficiency is "
                f"{float(kaggle['Fuel_Efficiency']):.2f} km/l."
            ),
            "mileage_km": max(0, baseline_mileage - 500),
            "cost": "0.00",
            "event_date": iso_date(service_date - timedelta(days=30)),
            "source": "Kaggle vehicle-maintenance-data (derived)",
            "source_id": vehicle_id,
        },
        {
            "vehicle_id": vehicle_id,
            "type": "service",
            "title": "Recorded maintenance baseline",
            "description": (
                f"Maintenance history: {kaggle['Maintenance_History']}; "
                f"service count: {kaggle['Service_History']}; "
                f"maintenance needed: {kaggle['Need_Maintenance']}."
            ),
            "mileage_km": baseline_mileage,
            "cost": "0.00",
            "event_date": iso_date(service_date),
            "source": "Kaggle vehicle-maintenance-data",
            "source_id": vehicle_id,
        },
    ]

    complaint = complaints[0] if complaints else {}
    complaint_date = parse_date(
        complaint.get("dateOfIncident") or complaint.get("dateComplaintFiled"),
        ["%m/%d/%Y"],
    )
    complaint_mileage = parse_failure_mileage_km(complaint.get("summary"))
    events.append(
        {
            "vehicle_id": vehicle_id,
            "type": "repair",
            "title": f"Owner complaint: {compact_text(complaint.get('components'), 80)}",
            "description": compact_text(complaint.get("summary")),
            "mileage_km": complaint_mileage or current_mileage,
            "cost": "0.00",
            "event_date": iso_date(complaint_date or service_date),
            "source": "NHTSA complaints API",
            "source_id": complaint.get("odiNumber", ""),
        }
    )

    recall = recalls[0] if recalls else {}
    recall_date = parse_date(recall.get("ReportReceivedDate"), ["%d/%m/%Y", "%m/%d/%Y"])
    events.append(
        {
            "vehicle_id": vehicle_id,
            "type": "service",
            "title": f"Recall: {compact_text(recall.get('Component'), 80)}",
            "description": compact_text(recall.get("Remedy") or recall.get("Summary")),
            "mileage_km": 0,
            "cost": "0.00",
            "event_date": iso_date(recall_date or service_date),
            "source": "NHTSA recalls API",
            "source_id": recall.get("NHTSACampaignNumber", ""),
        }
    )

    mot_event = latest_mot_event(dvsa_record or {}, vehicle_id, current_mileage)
    if mot_event:
        events[2] = mot_event
    return events


def component_name(bundle):
    complaint = bundle["complaints"][0] if bundle["complaints"] else {}
    recall = bundle["recalls"][0] if bundle["recalls"] else {}
    raw = complaint.get("components") or recall.get("Component") or "Vehicle component"
    first = re.split(r"[,;]", raw)[0]
    return first.replace(":", " / ").title()


def build_parts(bundle):
    vehicle = bundle["vehicle"]
    kaggle = bundle["kaggle"]
    vehicle_id = vehicle["id"]
    mileage = vehicle["mileage_km"]
    service_mileage = max(
        int(float(kaggle["Mileage"])),
        int(float(kaggle["Odometer_Reading"])),
    )
    complaint = bundle["complaints"][0] if bundle["complaints"] else {}
    return [
        {
            "vehicle_id": vehicle_id,
            "name": "Engine oil",
            "category": "fluids",
            "installed_at_mileage_km": max(0, service_mileage - 10000),
            "last_service_mileage_km": service_mileage,
            "source": "Kaggle vehicle-maintenance-data (normalized)",
            "source_id": vehicle_id,
        },
        {
            "vehicle_id": vehicle_id,
            "name": "Brake pads",
            "category": "brakes",
            "installed_at_mileage_km": max(0, mileage - 30000),
            "last_service_mileage_km": service_mileage,
            "source": "Kaggle vehicle-maintenance-data (normalized)",
            "source_id": kaggle["Brake_Condition"],
        },
        {
            "vehicle_id": vehicle_id,
            "name": "Timing belt",
            "category": "engine",
            "installed_at_mileage_km": max(0, mileage - 60000),
            "last_service_mileage_km": service_mileage,
            "source": "Kaggle vehicle-maintenance-data (normalized)",
            "source_id": kaggle["Maintenance_History"],
        },
        {
            "vehicle_id": vehicle_id,
            "name": component_name(bundle),
            "category": "reported component",
            "installed_at_mileage_km": "",
            "last_service_mileage_km": (
                parse_failure_mileage_km(complaint.get("summary")) or service_mileage
            ),
            "source": "NHTSA complaints/recalls API",
            "source_id": complaint.get("odiNumber", ""),
        },
    ]


def write_csv(path, fields, rows):
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", newline="", encoding="utf-8") as target:
        writer = csv.DictWriter(target, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    temporary.replace(path)


def validate_dataset(vehicles, events, parts):
    vehicle_ids = {row["id"] for row in vehicles}
    event_types = {row["type"] for row in events}
    if len(vehicles) < 10:
        raise RuntimeError("Dataset must contain at least 10 vehicles")
    if len(events) < 30:
        raise RuntimeError("Dataset must contain at least 30 events")
    if len(parts) < 30:
        raise RuntimeError("Dataset must contain at least 30 parts")
    if event_types != {"trip", "refuel", "repair", "service"}:
        raise RuntimeError(f"Unexpected event types: {event_types}")
    if any(row["vehicle_id"] not in vehicle_ids for row in events + parts):
        raise RuntimeError("An event or part references an unknown vehicle_id")
    if any(int(row["mileage_km"]) < 0 or float(row["cost"]) < 0 for row in events):
        raise RuntimeError("Event mileage and cost must be non-negative")


def main():
    parser = argparse.ArgumentParser(description="Build LAMBA demo CSV files from public APIs")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "demo_data",
    )
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument(
        "--vehicle-limit",
        type=int,
        default=len(VEHICLE_PROFILES),
        help=f"Number of vehicle profiles to collect (10-{len(VEHICLE_PROFILES)})",
    )
    parser.add_argument(
        "--dvsa-vins",
        help="Optional CSV with vehicle_id,vin; requires DVSA credentials in environment",
    )
    args = parser.parse_args()

    if not 10 <= args.vehicle_limit <= len(VEHICLE_PROFILES):
        parser.error(f"--vehicle-limit must be between 10 and {len(VEHICLE_PROFILES)}")

    profiles = VEHICLE_PROFILES[: args.vehicle_limit]
    kaggle_rows = load_kaggle_rows(args.timeout, len(profiles))
    bundles = {}
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = {
            executor.submit(
                fetch_vehicle_bundle,
                index,
                profile,
                kaggle_rows[index - 1],
                args.timeout,
            ): index
            for index, profile in enumerate(profiles, start=1)
        }
        for future in as_completed(futures):
            vehicle_id = futures[future]
            bundles[vehicle_id] = future.result()
            vehicle = bundles[vehicle_id]["vehicle"]
            print(f"Fetched {vehicle_id}: {vehicle['year']} {vehicle['brand']} {vehicle['model']}")

    dvsa_vins = load_dvsa_vins(args.dvsa_vins)
    dvsa_records = fetch_dvsa_records(dvsa_vins, args.timeout)

    vehicles = []
    events = []
    parts = []
    for vehicle_id in sorted(bundles):
        bundle = bundles[vehicle_id]
        vehicles.append(bundle["vehicle"])
        events.extend(build_events(bundle, dvsa_records.get(vehicle_id)))
        parts.extend(build_parts(bundle))

    for event_id, event in enumerate(events, start=1):
        event["id"] = event_id
    for part_id, part in enumerate(parts, start=1):
        part["id"] = part_id

    validate_dataset(vehicles, events, parts)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    write_csv(args.output_dir / "vehicles.csv", VEHICLE_FIELDS, vehicles)
    write_csv(args.output_dir / "vehicle_events.csv", EVENT_FIELDS, events)
    write_csv(args.output_dir / "parts.csv", PART_FIELDS, parts)
    print(
        f"Wrote {len(vehicles)} vehicles, {len(events)} events, "
        f"and {len(parts)} parts to {args.output_dir}"
    )


if __name__ == "__main__":
    main()
