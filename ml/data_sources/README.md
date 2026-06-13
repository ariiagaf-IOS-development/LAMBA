# Demo dataset sources

`build_demo_dataset.py` rebuilds the three CSV files in `ml/demo_data` from
the external sources listed in the assignment.

## Sources used automatically

- NHTSA vPIC API: model validation and partial VIN decoding.
- NHTSA complaints API: reported defects and failure descriptions.
- NHTSA recalls API: recall campaigns, components, dates, and remedies.
- CarAPI v2: year/make/model/trim, body, engine, fuel, and transmission data.
- Kaggle `chavindudulaj/vehicle-maintenance-data`: synthetic maintenance,
  mileage, fuel, and component-condition records.

The Kaggle source is synthetic by its own description. Events marked
`(derived)` are deterministic training events created from its fields because
the source does not contain individual trip and refuel rows.

VIN values returned by the complaints API are privacy-safe partial VINs, not
complete 17-character identifiers. vPIC supports decoding partial VINs.

## Run

The builder uses only the Python standard library:

```bash
python3 ml/data_sources/build_demo_dataset.py
```

The default build collects 30 vehicles and creates 150 events plus 120 part
records. For a smaller debugging run, use `--vehicle-limit` with a value from
10 to 30:

```bash
python3 ml/data_sources/build_demo_dataset.py --vehicle-limit 10
```

It produces:

```text
ml/demo_data/vehicles.csv
ml/demo_data/vehicle_events.csv
ml/demo_data/parts.csv
```

## Optional DVSA MOT history

DVSA does not provide anonymous access. Its API requires a registered client
ID, client secret, token URL, scope, API key, and full UK VINs. To replace the
Kaggle service baseline with a real MOT event, create a CSV:

```csv
vehicle_id,vin
1,FULL_17_CHARACTER_VIN
```

Then set the credentials issued by DVSA and run:

```bash
export DVSA_CLIENT_ID='...'
export DVSA_CLIENT_SECRET='...'
export DVSA_TOKEN_URL='...'
export DVSA_API_KEY='...'
export DVSA_SCOPE='https://tapi.dvsa.gov.uk/.default'
python3 ml/data_sources/build_demo_dataset.py --dvsa-vins path/to/dvsa_vins.csv
```

Do not commit DVSA credentials or VIN files containing private data.
