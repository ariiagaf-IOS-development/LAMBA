#!/usr/bin/env python3

import argparse
import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import sklearn
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    mean_absolute_error,
    mean_squared_error,
    r2_score,
)
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.tree import DecisionTreeRegressor


ML_ROOT = Path(__file__).resolve().parents[1]
BASELINE_DIR = ML_ROOT / "training" / "baseline"
ARTIFACT_DIR = ML_ROOT / "training" / "artifacts"
MODEL_VERSION = "maintenance-risk-baseline-v0.1"
RANDOM_STATE = 42

TARGET_COLUMN = "maintenance_needed"
DERIVED_RISK_TARGET = "risk_level"
DERIVED_REMAINING_TARGET = "remaining_km"

RISK_LEVEL_TO_SCORE = {
    "low": 20,
    "medium": 60,
    "high": 90,
}


def load_feature_schema(path):
    with open(path, "r", encoding="utf-8") as schema_file:
        return json.load(schema_file)


def feature_columns_from_schema(schema):
    return [feature["name"] for feature in schema["features"]]


def derive_risk_level(row):
    if int(row[TARGET_COLUMN]) == 0:
        return "low"

    score = 45
    if row.get("maintenance_history_score", -1) <= 0:
        score += 20
    if row.get("mileage_bucket") in {"high", "very_high"}:
        score += 15
    if row.get("avg_km_since_part_service", 0) >= 10000:
        score += 10
    if row.get("km_since_last_maintenance", 0) >= 10000:
        score += 10

    if score >= 70:
        return "high"
    return "medium"


def derive_remaining_km(row):
    avg_service_age = float(row.get("avg_km_since_part_service") or 0)
    km_since_maintenance = float(row.get("km_since_last_maintenance") or 0)
    usage_km = max(avg_service_age, km_since_maintenance)

    remaining = max(0, round(12000 - usage_km))
    risk_level = row[DERIVED_RISK_TARGET]

    if risk_level == "high":
        return int(min(remaining, 1000))
    if risk_level == "medium":
        return int(min(remaining, 3000))
    return int(max(remaining, 3000))


def add_derived_targets(frame):
    frame = frame.copy()
    frame[DERIVED_RISK_TARGET] = frame.apply(derive_risk_level, axis=1)
    frame[DERIVED_REMAINING_TARGET] = frame.apply(derive_remaining_km, axis=1)
    return frame


def split_feature_types(frame, feature_columns):
    categorical = []
    numeric = []
    for column in feature_columns:
        if frame[column].dtype == "object":
            categorical.append(column)
        else:
            numeric.append(column)
    return numeric, categorical


def build_preprocessor(numeric_features, categorical_features, scale_numeric):
    numeric_steps = [("imputer", SimpleImputer(strategy="median"))]
    if scale_numeric:
        numeric_steps.append(("scaler", StandardScaler()))

    numeric_pipeline = Pipeline(numeric_steps)
    categorical_pipeline = Pipeline([
        ("imputer", SimpleImputer(strategy="most_frequent")),
        ("onehot", OneHotEncoder(handle_unknown="ignore", sparse_output=False)),
    ])

    return ColumnTransformer([
        ("numeric", numeric_pipeline, numeric_features),
        ("categorical", categorical_pipeline, categorical_features),
    ])


def build_model_families(numeric_features, categorical_features):
    logistic_preprocessor = build_preprocessor(
        numeric_features,
        categorical_features,
        scale_numeric=True,
    )
    forest_preprocessor = build_preprocessor(
        numeric_features,
        categorical_features,
        scale_numeric=False,
    )

    return {
        "logistic_regression": {
            "classifier": Pipeline([
                ("preprocess", logistic_preprocessor),
                ("model", LogisticRegression(
                    max_iter=1000,
                    class_weight="balanced",
                    solver="liblinear",
                )),
            ]),
            "regressor": Pipeline([
                ("preprocess", forest_preprocessor),
                ("model", DecisionTreeRegressor(
                    random_state=RANDOM_STATE,
                    max_depth=4,
                    min_samples_leaf=2,
                )),
            ]),
            "remaining_km_model": "decision_tree_regressor",
        },
        "random_forest": {
            "classifier": Pipeline([
                ("preprocess", forest_preprocessor),
                ("model", RandomForestClassifier(
                    n_estimators=200,
                    random_state=RANDOM_STATE,
                    class_weight="balanced",
                    min_samples_leaf=1,
                )),
            ]),
            "regressor": Pipeline([
                ("preprocess", forest_preprocessor),
                ("model", RandomForestRegressor(
                    n_estimators=200,
                    random_state=RANDOM_STATE,
                    min_samples_leaf=1,
                )),
            ]),
            "remaining_km_model": "random_forest_regressor",
        },
    }


def evaluate_model_family(name, family, train, validation, feature_columns):
    x_train = train[feature_columns]
    y_train_risk = train[DERIVED_RISK_TARGET]
    y_train_remaining = train[DERIVED_REMAINING_TARGET]

    x_validation = validation[feature_columns]
    y_validation_risk = validation[DERIVED_RISK_TARGET]
    y_validation_remaining = validation[DERIVED_REMAINING_TARGET]

    family["classifier"].fit(x_train, y_train_risk)
    family["regressor"].fit(x_train, y_train_remaining)

    risk_predictions = family["classifier"].predict(x_validation)
    remaining_predictions = np.maximum(0, np.rint(family["regressor"].predict(x_validation))).astype(int)

    mae = mean_absolute_error(y_validation_remaining, remaining_predictions)
    rmse = mean_squared_error(y_validation_remaining, remaining_predictions) ** 0.5
    macro_f1 = f1_score(y_validation_risk, risk_predictions, average="macro", zero_division=0)

    return {
        "model_name": name,
        "remaining_km_model": family["remaining_km_model"],
        "metrics": {
            "risk_accuracy": round(accuracy_score(y_validation_risk, risk_predictions), 4),
            "risk_macro_f1": round(macro_f1, 4),
            "remaining_km_mae": round(mae, 2),
            "remaining_km_rmse": round(rmse, 2),
            "remaining_km_r2": round(r2_score(y_validation_remaining, remaining_predictions), 4),
        },
        "validation_predictions": [
            {
                "vehicle_id": int(vehicle_id),
                "actual_risk_level": actual_risk,
                "predicted_risk_level": predicted_risk,
                "actual_remaining_km": int(actual_remaining),
                "predicted_remaining_km": int(predicted_remaining),
            }
            for vehicle_id, actual_risk, predicted_risk, actual_remaining, predicted_remaining
            in zip(
                validation["vehicle_id"],
                y_validation_risk,
                risk_predictions,
                y_validation_remaining,
                remaining_predictions,
            )
        ],
    }


def selection_score(result):
    metrics = result["metrics"]
    normalized_mae_penalty = metrics["remaining_km_mae"] / 12000
    return metrics["risk_macro_f1"] - normalized_mae_penalty


def predict_one(artifact, row):
    frame = pd.DataFrame([row])[artifact["feature_columns"]]
    risk_level = artifact["classifier"].predict(frame)[0]
    risk_score = RISK_LEVEL_TO_SCORE[risk_level]
    remaining_km = int(max(0, round(artifact["regressor"].predict(frame)[0])))
    probability_by_class = {}

    classifier = artifact["classifier"]
    if hasattr(classifier.named_steps["model"], "predict_proba"):
        probabilities = classifier.predict_proba(frame)[0]
        classes = classifier.named_steps["model"].classes_
        probability_by_class = {
            str(label): round(float(probability), 4)
            for label, probability in zip(classes, probabilities)
        }

    return {
        "risk_level": str(risk_level),
        "risk_score": risk_score,
        "remaining_km": remaining_km,
        "probability_by_risk_level": probability_by_class,
    }


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as output_file:
        json.dump(payload, output_file, indent=2)
        output_file.write("\n")


def main():
    parser = argparse.ArgumentParser(description="Train first maintenance risk baseline models.")
    parser.add_argument("--train-csv", default=BASELINE_DIR / "train.csv", type=Path)
    parser.add_argument("--validation-csv", default=BASELINE_DIR / "validation.csv", type=Path)
    parser.add_argument("--feature-schema", default=BASELINE_DIR / "feature_schema.json", type=Path)
    parser.add_argument("--artifact-dir", default=ARTIFACT_DIR, type=Path)
    args = parser.parse_args()

    schema = load_feature_schema(args.feature_schema)
    feature_columns = feature_columns_from_schema(schema)
    train = add_derived_targets(pd.read_csv(args.train_csv))
    validation = add_derived_targets(pd.read_csv(args.validation_csv))

    numeric_features, categorical_features = split_feature_types(train, feature_columns)
    families = build_model_families(numeric_features, categorical_features)

    comparison = []
    for name, family in families.items():
        comparison.append(evaluate_model_family(name, family, train, validation, feature_columns))

    best_result = max(comparison, key=selection_score)
    best_name = best_result["model_name"]
    best_family = families[best_name]

    artifact = {
        "model_version": MODEL_VERSION,
        "sklearn_version": sklearn.__version__,
        "selected_model": best_name,
        "classifier": best_family["classifier"],
        "regressor": best_family["regressor"],
        "feature_columns": feature_columns,
        "numeric_features": numeric_features,
        "categorical_features": categorical_features,
        "risk_level_to_score": RISK_LEVEL_TO_SCORE,
        "target_definitions": {
            DERIVED_RISK_TARGET: "Derived low/medium/high maintenance risk target.",
            DERIVED_REMAINING_TARGET: "Derived remaining kilometers until recommended maintenance.",
        },
    }

    args.artifact_dir.mkdir(parents=True, exist_ok=True)
    artifact_path = args.artifact_dir / "maintenance_risk_model.joblib"
    comparison_path = args.artifact_dir / "model_comparison.json"
    inference_path = args.artifact_dir / "sample_inference.json"

    joblib.dump(artifact, artifact_path)

    sample_row = validation.iloc[0].to_dict()
    inference = {
        "model_version": MODEL_VERSION,
        "selected_model": best_name,
        "vehicle_id": int(sample_row["vehicle_id"]),
        "prediction": predict_one(artifact, sample_row),
    }

    report = {
        "model_version": MODEL_VERSION,
        "sklearn_version": sklearn.__version__,
        "train_rows": int(len(train)),
        "validation_rows": int(len(validation)),
        "feature_count": int(len(feature_columns)),
        "risk_level_distribution": {
            "train": train[DERIVED_RISK_TARGET].value_counts().sort_index().to_dict(),
            "validation": validation[DERIVED_RISK_TARGET].value_counts().sort_index().to_dict(),
        },
        "models": comparison,
        "selected_model": best_name,
        "selection_rule": "Highest risk_macro_f1 minus remaining_km_mae / 12000.",
        "artifact_path": str(artifact_path.relative_to(ML_ROOT.parent)),
        "sample_inference_path": str(inference_path.relative_to(ML_ROOT.parent)),
    }

    write_json(comparison_path, report)
    write_json(inference_path, inference)

    print(f"trained_models={','.join(sorted(families))}")
    print(f"selected_model={best_name}")
    print(f"artifact={artifact_path}")
    print(f"comparison={comparison_path}")
    print(f"sample_inference={inference_path}")


if __name__ == "__main__":
    main()
