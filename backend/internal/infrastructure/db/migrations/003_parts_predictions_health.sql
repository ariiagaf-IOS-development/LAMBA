CREATE TABLE IF NOT EXISTS parts_catalog (
	id BIGSERIAL PRIMARY KEY,
	code TEXT NOT NULL UNIQUE,
	name TEXT NOT NULL,
	category TEXT NOT NULL,
	default_lifetime_km INTEGER NOT NULL,
	default_lifetime_days INTEGER NOT NULL,
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

	CONSTRAINT parts_catalog_code_not_blank CHECK (length(btrim(code)) > 0),
	CONSTRAINT parts_catalog_name_not_blank CHECK (length(btrim(name)) > 0),
	CONSTRAINT parts_catalog_category_not_blank CHECK (length(btrim(category)) > 0),
	CONSTRAINT parts_catalog_lifetime_km_positive CHECK (default_lifetime_km > 0),
	CONSTRAINT parts_catalog_lifetime_days_positive CHECK (default_lifetime_days > 0)
);

INSERT INTO parts_catalog (
	code,
	name,
	category,
	default_lifetime_km,
	default_lifetime_days
)
VALUES
	('engine_oil', 'Engine oil', 'fluids', 10000, 365),
	('oil_filter', 'Oil filter', 'filters', 10000, 365),
	('air_filter', 'Air filter', 'filters', 15000, 365),
	('cabin_filter', 'Cabin filter', 'filters', 15000, 365),
	('brake_pads', 'Brake pads', 'brakes', 40000, 1095),
	('tires', 'Tires', 'wheels', 50000, 1825),
	('battery', 'Battery', 'electric', 60000, 1460),
	('spark_plugs', 'Spark plugs', 'engine', 30000, 1095),
	('transmission_oil', 'Transmission oil', 'fluids', 60000, 1825),
	('coolant', 'Coolant', 'fluids', 50000, 1095)
ON CONFLICT (code) DO NOTHING;

ALTER TABLE parts
	ADD COLUMN IF NOT EXISTS catalog_code TEXT,
	ADD COLUMN IF NOT EXISTS last_service_date TIMESTAMPTZ,
	ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE parts
	DROP CONSTRAINT IF EXISTS parts_catalog_code_fk;

ALTER TABLE parts
	ADD CONSTRAINT parts_catalog_code_fk
	FOREIGN KEY (catalog_code)
	REFERENCES parts_catalog(code)
	ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS parts_catalog_code_idx ON parts_catalog (code);
CREATE INDEX IF NOT EXISTS parts_vehicle_catalog_code_idx ON parts (vehicle_id, catalog_code);

ALTER TABLE predictions
	ADD COLUMN IF NOT EXISTS part_category TEXT,
	ADD COLUMN IF NOT EXISTS part_code TEXT,
	ADD COLUMN IF NOT EXISTS risk_score INTEGER,
	ADD COLUMN IF NOT EXISTS remaining_days INTEGER,
	ADD COLUMN IF NOT EXISTS predicted_next_mileage INTEGER,
	ADD COLUMN IF NOT EXISTS predicted_next_date DATE,
	ADD COLUMN IF NOT EXISTS explanation TEXT;

ALTER TABLE predictions
	DROP CONSTRAINT IF EXISTS predictions_risk_score_range,
	ADD CONSTRAINT predictions_risk_score_range
	CHECK (risk_score IS NULL OR (risk_score >= 0 AND risk_score <= 100));

ALTER TABLE predictions
	DROP CONSTRAINT IF EXISTS predictions_remaining_days_non_negative,
	ADD CONSTRAINT predictions_remaining_days_non_negative
	CHECK (remaining_days IS NULL OR remaining_days >= 0);

ALTER TABLE predictions
	DROP CONSTRAINT IF EXISTS predictions_predicted_next_mileage_non_negative,
	ADD CONSTRAINT predictions_predicted_next_mileage_non_negative
	CHECK (predicted_next_mileage IS NULL OR predicted_next_mileage >= 0);

ALTER TABLE predictions
	DROP CONSTRAINT IF EXISTS predictions_explanation_not_blank,
	ADD CONSTRAINT predictions_explanation_not_blank
	CHECK (explanation IS NULL OR length(btrim(explanation)) > 0);

CREATE INDEX IF NOT EXISTS predictions_vehicle_created_at_idx
	ON predictions (vehicle_id, created_at DESC);

CREATE INDEX IF NOT EXISTS predictions_vehicle_part_code_idx
	ON predictions (vehicle_id, part_code);