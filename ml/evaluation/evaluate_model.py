#!/usr/bin/env python3

import argparse
import json
import sys
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    mean_absolute_error,
    mean_squared_error,
    precision_score,
    r2_score,
    recall_score,
)


ML_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = ML_ROOT.parent
DEFAULT_ARTIFACT = ML_ROOT / "training" / "artifacts" / "maintenance_risk_model.joblib"
DEFAULT_VALIDATION = ML_ROOT / "training" / "baseline" / "validation.csv"
DEFAULT_METRICS = ML_ROOT / "evaluation" / "metrics.json"
DEFAULT_REPORT = ML_ROOT / "evaluation" / "evaluation_report.md"

if str(ML_ROOT) not in sys.path:
    sys.path.insert(0, str(ML_ROOT))

from training.train_maintenance_baselines import (  # noqa: E402
    DERIVED_REMAINING_TARGET,
    DERIVED_RISK_TARGET,
    add_derived_targets,
)


def _relative(path: Path) -> str:
    return str(path.resolve().relative_to(PROJECT_ROOT))


def _predict(artifact: dict, validation: pd.DataFrame) -> tuple[np.ndarray, np.ndarray]:
    features = validation[artifact["feature_columns"]]
    risk_predictions = artifact["classifier"].predict(features)
    remaining_predictions = np.maximum(
        0,
        np.rint(artifact["regressor"].predict(features)),
    ).astype(int)
    return risk_predictions, remaining_predictions


def build_metrics(artifact_path: Path, validation_path: Path) -> dict:
    artifact = joblib.load(artifact_path)
    validation = add_derived_targets(pd.read_csv(validation_path))
    risk_predictions, remaining_predictions = _predict(artifact, validation)

    actual_risk = validation[DERIVED_RISK_TARGET]
    actual_remaining = validation[DERIVED_REMAINING_TARGET]
    labels = ["low", "medium", "high"]

    metrics = {
        "model_version": artifact["model_version"],
        "selected_model": artifact["selected_model"],
        "artifact_path": _relative(artifact_path),
        "validation_path": _relative(validation_path),
        "validation_rows": int(len(validation)),
        "feature_count": int(len(artifact["feature_columns"])),
        "classification": {
            "labels": labels,
            "accuracy": round(float(accuracy_score(actual_risk, risk_predictions)), 4),
            "precision_macro": round(float(precision_score(
                actual_risk,
                risk_predictions,
                average="macro",
                zero_division=0,
            )), 4),
            "recall_macro": round(float(recall_score(
                actual_risk,
                risk_predictions,
                average="macro",
                zero_division=0,
            )), 4),
            "f1_macro": round(float(f1_score(
                actual_risk,
                risk_predictions,
                average="macro",
                zero_division=0,
            )), 4),
            "confusion_matrix": confusion_matrix(
                actual_risk,
                risk_predictions,
                labels=labels,
            ).tolist(),
            "per_class": classification_report(
                actual_risk,
                risk_predictions,
                labels=labels,
                zero_division=0,
                output_dict=True,
            ),
        },
        "remaining_km_regression": {
            "mae": round(float(mean_absolute_error(actual_remaining, remaining_predictions)), 2),
            "rmse": round(float(mean_squared_error(actual_remaining, remaining_predictions) ** 0.5), 2),
            "r2": round(float(r2_score(actual_remaining, remaining_predictions)), 4),
        },
        "validation_predictions": [
            {
                "vehicle_id": int(vehicle_id),
                "actual_risk_level": str(actual),
                "predicted_risk_level": str(predicted),
                "actual_remaining_km": int(actual_km),
                "predicted_remaining_km": int(predicted_km),
            }
            for vehicle_id, actual, predicted, actual_km, predicted_km in zip(
                validation["vehicle_id"],
                actual_risk,
                risk_predictions,
                actual_remaining,
                remaining_predictions,
            )
        ],
        "notes": [
            "Validation split is intentionally small and should be treated as a baseline smoke-test.",
            "Metrics are generated from the persisted model artifact, not from retraining.",
        ],
    }
    return metrics


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as output_file:
        json.dump(payload, output_file, indent=2)
        output_file.write("\n")


def write_report(path: Path, metrics: dict) -> None:
    classification = metrics["classification"]
    regression = metrics["remaining_km_regression"]

    lines = [
        "# Maintenance Risk Model Evaluation",
        "",
        "## Summary",
        "",
        f"- Model version: `{metrics['model_version']}`",
        f"- Selected model: `{metrics['selected_model']}`",
        f"- Validation rows: `{metrics['validation_rows']}`",
        f"- Feature count: `{metrics['feature_count']}`",
        f"- Artifact: `{metrics['artifact_path']}`",
        "",
        "## Classification Metrics",
        "",
        "| Metric | Value |",
        "| --- | ---: |",
        f"| Accuracy | {classification['accuracy']} |",
        f"| Precision macro | {classification['precision_macro']} |",
        f"| Recall macro | {classification['recall_macro']} |",
        f"| F1 macro | {classification['f1_macro']} |",
        "",
        "## Remaining Kilometer Metrics",
        "",
        "| Metric | Value |",
        "| --- | ---: |",
        f"| MAE | {regression['mae']} km |",
        f"| RMSE | {regression['rmse']} km |",
        f"| R2 | {regression['r2']} |",
        "",
        "## Confusion Matrix",
        "",
        "Rows are actual labels; columns are predicted labels.",
        "",
        "| Actual \\ Predicted | low | medium | high |",
        "| --- | ---: | ---: | ---: |",
    ]

    for label, row in zip(classification["labels"], classification["confusion_matrix"]):
        lines.append(f"| {label} | {row[0]} | {row[1]} | {row[2]} |")

    lines.extend([
        "",
        "## Validation Predictions",
        "",
        "| Vehicle ID | Actual risk | Predicted risk | Actual remaining km | Predicted remaining km |",
        "| ---: | --- | --- | ---: | ---: |",
    ])

    for item in metrics["validation_predictions"]:
        lines.append(
            "| {vehicle_id} | {actual_risk_level} | {predicted_risk_level} | "
            "{actual_remaining_km} | {predicted_remaining_km} |".format(**item)
        )

    lines.extend([
        "",
        "## Notes",
        "",
    ])
    lines.extend(f"- {note}" for note in metrics["notes"])
    lines.append("")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate persisted maintenance risk model artifact.")
    parser.add_argument("--artifact", default=DEFAULT_ARTIFACT, type=Path)
    parser.add_argument("--validation-csv", default=DEFAULT_VALIDATION, type=Path)
    parser.add_argument("--metrics-output", default=DEFAULT_METRICS, type=Path)
    parser.add_argument("--report-output", default=DEFAULT_REPORT, type=Path)
    args = parser.parse_args()

    metrics = build_metrics(args.artifact, args.validation_csv)
    write_json(args.metrics_output, metrics)
    write_report(args.report_output, metrics)

    print(f"metrics={args.metrics_output}")
    print(f"report={args.report_output}")


if __name__ == "__main__":
    main()
