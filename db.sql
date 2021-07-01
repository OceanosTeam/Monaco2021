CREATE TABLE raw_can (
	t timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
	id bit(29),
	data bytea,
	PRIMARY KEY (t, id)
);

CREATE INDEX raw_can_id ON raw_can (id);

CREATE VIEW controller AS
	SELECT
		t,
		(get_byte(data, 0) | (get_byte(data, 1) << 8)) speed,
		(get_byte(data, 2) | (get_byte(data, 3) << 8)) * 100 AS current,
		(get_byte(data, 4) | (get_byte(data, 5) << 8)) * 100 voltage,
		get_bit(data, 6*8 +  0)::boolean error_id,
		get_bit(data, 6*8 +  1)::boolean error_overvolt,
		get_bit(data, 6*8 +  2)::boolean error_undervolt,
		get_bit(data, 6*8 +  4)::boolean error_stall,
		get_bit(data, 6*8 +  5)::boolean error_internal,
		get_bit(data, 6*8 +  6)::boolean error_controller_temp,
		get_bit(data, 6*8 +  7)::boolean error_throttle_start,
		get_bit(data, 6*8 +  9)::boolean error_reset,
		get_bit(data, 6*8 + 10)::boolean error_throttle_hall,
		get_bit(data, 6*8 + 11)::boolean error_angle,
		get_bit(data, 6*8 + 14)::boolean error_motor_temp,
		get_bit(data, 6*8 + 15)::boolean error_hall_galvanometer
	FROM
		raw_can
	WHERE
		-- The constant is a bit(32).  Casting to a bit(29) truncates the low bits;
		-- the ones that we really care about.  So we shift
		id = (x'0CF11E05' << 3)::bit(29);

CREATE TYPE direction AS ENUM (
	'stationary',
	'forwards',
	'backwards',
	'reserved'
);

CREATE VIEW controller_status AS
	SELECT
		t,
		get_byte(data, 0) throttle,
		get_byte(data, 1) - 40 controller_temp,
		get_byte(data, 2) - 30 motor_temp,
		CASE get_bit(data, 3*8 + 0) | (get_bit(data, 3*8 + 1) << 1)
			WHEN 0 THEN direction 'stationary'
			WHEN 1 THEN direction 'forwards'
			WHEN 2 THEN direction 'backwards'
			WHEN 3 THEN direction 'reserved'
		END command,
		CASE get_bit(data, 3*8 + 2) | (get_bit(data, 3*8 + 3) << 1)
			WHEN 0 THEN direction 'stationary'
			WHEN 1 THEN direction 'forwards'
			WHEN 2 THEN direction 'backwards'
			WHEN 3 THEN direction 'reserved'
		END feedback,
		get_bit(data, 4*8 + 0)::boolean hall_a,
		get_bit(data, 4*8 + 1)::boolean hall_b,
		get_bit(data, 4*8 + 2)::boolean hall_c,
		get_bit(data, 4*8 + 3)::boolean switch_brake,
		get_bit(data, 4*8 + 4)::boolean switch_backward,
		get_bit(data, 4*8 + 5)::boolean switch_forward,
		get_bit(data, 4*8 + 6)::boolean switch_foot,
		get_bit(data, 4*8 + 7)::boolean switch_boost
	FROM
		raw_can
	WHERE
		id = (x'0CF11F05' << 3)::bit(29);
