CREATE TABLE IF NOT EXISTS users (
	id BIGSERIAL PRIMARY KEY,
	email TEXT NOT NULL,
	password_hash TEXT NOT NULL,
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	CONSTRAINT users_email_not_blank CHECK (length(btrim(email)) > 0),
	CONSTRAINT users_password_hash_not_blank CHECK (length(btrim(password_hash)) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique ON users (lower(email));

CREATE TABLE IF NOT EXISTS vehicles (
	id BIGSERIAL PRIMARY KEY,
	user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	brand TEXT NOT NULL,
	model TEXT NOT NULL,
	year INTEGER NOT NULL,
	vin TEXT,
	mileage_km INTEGER NOT NULL DEFAULT 0,
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	CONSTRAINT vehicles_brand_not_blank CHECK (length(btrim(brand)) > 0),
	CONSTRAINT vehicles_model_not_blank CHECK (length(btrim(model)) > 0),
	CONSTRAINT vehicles_year_range CHECK (year >= 1886 AND year <= 2100),
	CONSTRAINT vehicles_mileage_non_negative CHECK (mileage_km >= 0)
);

CREATE INDEX IF NOT EXISTS vehicles_user_id_idx ON vehicles (user_id);
CREATE UNIQUE INDEX IF NOT EXISTS vehicles_user_vin_unique
	ON vehicles (user_id, lower(vin))
	WHERE vin IS NOT NULL AND length(btrim(vin)) > 0;

CREATE TABLE IF NOT EXISTS vehicle_events (
	id BIGSERIAL PRIMARY KEY,
	vehicle_id BIGINT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
	type TEXT NOT NULL,
	title TEXT NOT NULL,
	description TEXT,
	mileage_km INTEGER NOT NULL,
	cost NUMERIC(12, 2) NOT NULL DEFAULT 0,
	event_date TIMESTAMPTZ NOT NULL,
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	CONSTRAINT vehicle_events_type_allowed CHECK (type IN ('trip', 'refuel', 'repair', 'service')),
	CONSTRAINT vehicle_events_title_not_blank CHECK (length(btrim(title)) > 0),
	CONSTRAINT vehicle_events_mileage_non_negative CHECK (mileage_km >= 0),
	CONSTRAINT vehicle_events_cost_non_negative CHECK (cost >= 0)
);

CREATE INDEX IF NOT EXISTS vehicle_events_vehicle_id_idx ON vehicle_events (vehicle_id);

CREATE TABLE IF NOT EXISTS parts (
	id BIGSERIAL PRIMARY KEY,
	vehicle_id BIGINT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
	name TEXT NOT NULL,
	category TEXT,
	installed_at_mileage_km INTEGER,
	last_service_mileage_km INTEGER,
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	CONSTRAINT parts_name_not_blank CHECK (length(btrim(name)) > 0),
	CONSTRAINT parts_installed_mileage_non_negative CHECK (installed_at_mileage_km IS NULL OR installed_at_mileage_km >= 0),
	CONSTRAINT parts_last_service_mileage_non_negative CHECK (last_service_mileage_km IS NULL OR last_service_mileage_km >= 0)
);

CREATE INDEX IF NOT EXISTS parts_vehicle_id_idx ON parts (vehicle_id);

CREATE TABLE IF NOT EXISTS predictions (
	id BIGSERIAL PRIMARY KEY,
	vehicle_id BIGINT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
	part_name TEXT NOT NULL,
	risk_level TEXT NOT NULL,
	remaining_km INTEGER,
	probability NUMERIC(5, 4),
	recommendation TEXT NOT NULL,
	source TEXT NOT NULL DEFAULT 'ml_service',
	model_version TEXT,
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	CONSTRAINT predictions_part_name_not_blank CHECK (length(btrim(part_name)) > 0),
	CONSTRAINT predictions_risk_level_allowed CHECK (risk_level IN ('low', 'medium', 'high')),
	CONSTRAINT predictions_remaining_km_non_negative CHECK (remaining_km IS NULL OR remaining_km >= 0),
	CONSTRAINT predictions_probability_range CHECK (probability IS NULL OR (probability >= 0 AND probability <= 1)),
	CONSTRAINT predictions_recommendation_not_blank CHECK (length(btrim(recommendation)) > 0)
);

CREATE INDEX IF NOT EXISTS predictions_vehicle_id_idx ON predictions (vehicle_id);

CREATE TABLE IF NOT EXISTS chat_messages (
	id BIGSERIAL PRIMARY KEY,
	vehicle_id BIGINT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
	role TEXT NOT NULL,
	message TEXT NOT NULL,
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	CONSTRAINT chat_messages_role_allowed CHECK (role IN ('user', 'assistant', 'system')),
	CONSTRAINT chat_messages_message_not_blank CHECK (length(btrim(message)) > 0)
);

CREATE INDEX IF NOT EXISTS chat_messages_vehicle_id_idx ON chat_messages (vehicle_id);
