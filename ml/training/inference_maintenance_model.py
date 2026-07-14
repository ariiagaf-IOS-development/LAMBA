#!/usr/bin/env python3

import argparse
import json
from pathlib import Path

import joblib
import pandas as pd


ML_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ARTIFACT = ML_ROOT / "training" / "artifacts" / "maintenance_risk_model.joblib"
DEFAULT_INPUT = ML_ROOT / "training" / "baseline" / "validation.csv"


def predict_row(artifact, row):
    frame = pd.DataFrame([row])[artifact["feature_columns"]]
    risk_level = artifact["classifier"].predict(frame)[0]
    remaining_km = int(max(0, round(artifact["regressor"].predict(frame)[0])))
    risk_score = artifact["risk_level_to_score"][risk_level]

    probability_by_risk_level = {}
    model = artifact["classifier"].named_steps["model"]
    if hasattr(model, "predict_proba"):
        probabilities = artifact["classifier"].predict_proba(frame)[0]
        probability_by_risk_level = {
            str(label): round(float(probability), 4)
            for label, probability in zip(model.classes_, probabilities)
        }

    return {
        "vehicle_id": int(row["vehicle_id"]),
        "model_version": artifact["model_version"],
        "selected_model": artifact["selected_model"],
        "risk_level": str(risk_level),
        "risk_score": int(risk_score),
        "remaining_km": remaining_km,
        "probability_by_risk_level": probability_by_risk_level,
    }


def main():
    parser = argparse.ArgumentParser(description="Run inference with the maintenance risk baseline artifact.")
    parser.add_argument("--artifact", default=DEFAULT_ARTIFACT, type=Path)
    parser.add_argument("--input-csv", default=DEFAULT_INPUT, type=Path)
    parser.add_argument("--row-index", default=0, type=int)
    args = parser.parse_args()

    artifact = joblib.load(args.artifact)
    rows = pd.read_csv(args.input_csv)
    row = rows.iloc[args.row_index].to_dict()
    prediction = predict_row(artifact, row)
    print(json.dumps(prediction, indent=2))


if __name__ == "__main__":
    main()
