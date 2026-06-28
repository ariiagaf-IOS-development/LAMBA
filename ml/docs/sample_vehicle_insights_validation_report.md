# Sample Vehicle Insights Validation Report

## Summary

- Insights file: `ml/insights/sample_vehicle_insights.json`
- Schema version: `sample-vehicle-insights-v0.1`
- Model version: `sample-insights-rules-v0.1`
- Vehicles tested: 30
- Insights tested: 90
- Validation status: passed

## Source Data

- `ml/demo_data/parts.csv`
- `ml/demo_data/vehicle_events.csv`
- `ml/demo_data/vehicles.csv`

## Insight Coverage

| Category | Count |
| --- | ---: |
| `cost` | 30 |
| `maintenance` | 30 |
| `risk_prediction` | 30 |

| Severity | Count |
| --- | ---: |
| `low` | 84 |
| `medium` | 6 |

## Per-Vehicle Results

| Vehicle | Insights | Categories | Top severity |
| --- | ---: | --- | --- |
| 2018 Toyota Camry | 3 | maintenance, cost, risk_prediction | low |
| 2019 Toyota Corolla | 3 | maintenance, cost, risk_prediction | low |
| 2020 Toyota RAV4 | 3 | maintenance, cost, risk_prediction | low |
| 2020 Honda Civic | 3 | maintenance, cost, risk_prediction | low |
| 2019 Honda Accord | 3 | maintenance, cost, risk_prediction | low |
| 2020 Honda CR-V | 3 | maintenance, cost, risk_prediction | low |
| 2019 Ford Escape | 3 | maintenance, cost, risk_prediction | low |
| 2020 Ford Explorer | 3 | maintenance, cost, risk_prediction | medium |
| 2019 Ford Mustang | 3 | maintenance, cost, risk_prediction | low |
| 2020 Chevrolet Equinox | 3 | maintenance, cost, risk_prediction | medium |
| 2019 Chevrolet Malibu | 3 | maintenance, cost, risk_prediction | low |
| 2020 Chevrolet Traverse | 3 | maintenance, cost, risk_prediction | low |
| 2019 Nissan Rogue | 3 | maintenance, cost, risk_prediction | low |
| 2020 Nissan Altima | 3 | maintenance, cost, risk_prediction | low |
| 2019 Nissan Sentra | 3 | maintenance, cost, risk_prediction | low |
| 2018 Hyundai Sonata | 3 | maintenance, cost, risk_prediction | low |
| 2020 Hyundai Elantra | 3 | maintenance, cost, risk_prediction | low |
| 2019 Hyundai Tucson | 3 | maintenance, cost, risk_prediction | low |
| 2020 Kia Sportage | 3 | maintenance, cost, risk_prediction | low |
| 2019 Kia Optima | 3 | maintenance, cost, risk_prediction | low |
| 2020 Kia Sorento | 3 | maintenance, cost, risk_prediction | low |
| 2019 Volkswagen Jetta | 3 | maintenance, cost, risk_prediction | low |
| 2020 Volkswagen Tiguan | 3 | maintenance, cost, risk_prediction | low |
| 2018 Volkswagen Passat | 3 | maintenance, cost, risk_prediction | low |
| 2018 Mazda CX-5 | 3 | maintenance, cost, risk_prediction | medium |
| 2019 Mazda CX-9 | 3 | maintenance, cost, risk_prediction | low |
| 2020 Mazda CX-3 | 3 | maintenance, cost, risk_prediction | low |
| 2020 Subaru Outback | 3 | maintenance, cost, risk_prediction | low |
| 2019 Subaru Forester | 3 | maintenance, cost, risk_prediction | low |
| 2020 Subaru Impreza | 3 | maintenance, cost, risk_prediction | low |

## Validation Rules

- Each sample vehicle must have exactly 3 insights: maintenance, cost, and risk/prediction.
- Every insight must include evidence tied to the sample vehicle, part, event, or derived prediction.
- Insight source files must be limited to the provided demo CSV data.
- Cost insights must not invent repair prices when the sample data has no non-zero costs.
- Messages must be understandable to non-technical users and avoid low-level diagnostic jargon.

## Failure Modes And Edge Cases

- Demo cost fields are mostly zero, so the correct insight is limited-cost-data rather than a made-up estimate.
- Recall rows are represented as service events in the sample data; insight logic treats recall titles/sources separately from normal service.
- Reported complaint parts are not always supported by the parts-health rules, so risk/prediction insights use supported maintenance parts.
- Rule-based predictions are estimates from sample mileage/service/part rows and must not be described as confirmed failures.

## Team Handoff Notes

- Backend can use this JSON shape as a draft response contract for generated insights.
- Frontend can render the three categories as separate cards or list rows per vehicle.
- Product/QA should review the generated text for tone, but the current validation confirms source grounding and minimum coverage.
