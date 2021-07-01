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
		get_byte(data, 0) | (get_byte(data, 1) << 8) AS speed,
		100 * (get_byte(data, 2) | (get_byte(data, 3) << 8)) AS current,
		100 * (get_byte(data, 4) | (get_byte(data, 5) << 8)) AS voltage,
		CAST(get_bit(data, 6*8 + 0) AS boolean) AS error_id,
		CAST(get_bit(data, 6*8 + 1) AS boolean) AS error_overvolt,
		CAST(get_bit(data, 6*8 + 2) AS boolean) AS error_undervolt,
		CAST(get_bit(data, 6*8 + 4) AS boolean) AS error_stall,
		CAST(get_bit(data, 6*8 + 5) AS boolean) AS error_internal,
		CAST(get_bit(data, 6*8 + 6) AS boolean) AS error_controller_temp,
		CAST(get_bit(data, 6*8 + 7) AS boolean) AS error_throttle_start,
		CAST(get_bit(data, 6*8 + 9) AS boolean) AS error_reset,
		CAST(get_bit(data, 6*8 + 10) AS boolean) AS error_throttle_hall,
		CAST(get_bit(data, 6*8 + 11) AS boolean) AS error_angle,
		CAST(get_bit(data, 6*8 + 14) AS boolean) AS error_motor_temp,
		CAST(get_bit(data, 6*8 + 15) AS boolean) AS error_hall_galvanometer
	FROM
		raw_can
	WHERE
		id = CAST(x'0CF11E05' << 3 AS bit(29));

CREATE TYPE direction AS ENUM (
	'stationary',
	'forwards',
	'backwards',
	'reserved'
);

CREATE VIEW controller_status AS
	SELECT
		t,
		get_byte(data, 0) AS throttle,
		get_byte(data, 1) - 40 AS controller_temp,
		get_byte(data, 2) - 30 AS motor_temp,
		CASE get_bit(data, 3*8 + 0) | (get_bit(data, 3*8 + 1) << 1)
			WHEN 0 THEN CAST('stationary' AS direction)
			WHEN 1 THEN CAST('forwards' AS direction)
			WHEN 2 THEN CAST('backwards' AS direction)
			WHEN 3 THEN CAST('reserved' AS direction)
		END AS command,
		CASE get_bit(data, 3*8 + 2) | (get_bit(data, 3*8 + 3) << 1)
			WHEN 0 THEN CAST('stationary' AS direction)
			WHEN 1 THEN CAST('forwards' AS direction)
			WHEN 2 THEN CAST('backwards' AS direction)
			WHEN 3 THEN CAST('reserved' AS direction)
		END AS feedback,
		CAST(get_bit(data, 4*8 + 0) AS boolean) AS hall_a,
		CAST(get_bit(data, 4*8 + 1) AS boolean) AS hall_b,
		CAST(get_bit(data, 4*8 + 2) AS boolean) AS hall_c,
		CAST(get_bit(data, 4*8 + 3) AS boolean) AS brake_switch,
		CAST(get_bit(data, 4*8 + 4) AS boolean) AS backward_switch,
		CAST(get_bit(data, 4*8 + 5) AS boolean) AS forward_switch,
		CAST(get_bit(data, 4*8 + 6) AS boolean) AS foot_switch,
		CAST(get_bit(data, 4*8 + 7) AS boolean) AS boost_switch
	FROM
		raw_can
	WHERE
		id = CAST(x'0CF11F05' << 3 AS bit(29));
