from pathlib import Path
import pandas as pd

ML_ROOT = Path(__file__).resolve().parents[1]
DEMO_DATA_DIR = ML_ROOT / "demo_data"

def load_vehicles(data_dir=DEMO_DATA_DIR):
    return pd.read_csv(Path(data_dir) / "vehicles.csv")

def load_events(data_dir=DEMO_DATA_DIR):
    return pd.read_csv(Path(data_dir) / "vehicle_events.csv")

def load_parts(data_dir=DEMO_DATA_DIR):
    return pd.read_csv(Path(data_dir) / "parts.csv")

def load_all(data_dir=DEMO_DATA_DIR):
    return {
        "vehicles": load_vehicles(data_dir),
        "events": load_events(data_dir),
        "parts": load_parts(data_dir),
    }

if __name__ == "__main__":
    data = load_all()
    print("vehicles:", data["vehicles"].shape)
    print("events:", data["events"].shape)
    print("parts:", data["parts"].shape)