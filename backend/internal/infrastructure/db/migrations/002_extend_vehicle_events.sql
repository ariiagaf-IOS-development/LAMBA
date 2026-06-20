ALTER TABLE vehicle_events
	DROP CONSTRAINT IF EXISTS vehicle_events_type_allowed;

UPDATE vehicle_events
SET type = 'refuel'
WHERE type = 'fuel';

UPDATE vehicle_events
SET type = 'maintenance'
WHERE type = 'service';

ALTER TABLE vehicle_events
	ADD CONSTRAINT vehicle_events_type_allowed
	CHECK (
		type IN (
			'trip',
			'refuel',
			'repair',
			'inspection',
			'accident',
			'recall',
			'warning',
			'maintenance',
			'prediction',
			'diagnostic',
			'part_replacement',
			'note'
		)
	);

ALTER TABLE vehicle_events
	ALTER COLUMN metadata SET DEFAULT '{}'::jsonb;

UPDATE vehicle_events
SET metadata = '{}'::jsonb
WHERE metadata IS NULL;

ALTER TABLE vehicle_events
	ALTER COLUMN metadata SET NOT NULL;

CREATE INDEX IF NOT EXISTS vehicle_events_vehicle_event_date_idx
	ON vehicle_events (vehicle_id, event_date DESC, id DESC);

CREATE INDEX IF NOT EXISTS vehicle_events_vehicle_type_idx
	ON vehicle_events (vehicle_id, type);

CREATE INDEX IF NOT EXISTS vehicle_events_type_idx
	ON vehicle_events (type);

CREATE INDEX IF NOT EXISTS vehicle_events_event_date_idx
	ON vehicle_events (event_date DESC);