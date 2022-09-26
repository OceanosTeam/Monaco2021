/*
 * To import the data use:
 *   tail -n +2 data.csv | psql -c "COPY telemetry_old_can FROM STDIN WITH (FORMAT csv, DELIMITER ',', HEADER true);"
 */

CREATE TABLE IF NOT EXISTS telemetry_old_can_csv (
  date DATE,
  time TIME,
  microseconds INT,
  speed INT,
  throttle INT,
  current FLOAT,
  voltage FLOAT,
  controller_temp INT,
  motor_temp INT,
  motor_error_code CHAR(10),
  controller_status CHAR(10),
  switches_status CHAR(10),
  discharge FLOAT
  PRIMARY KEY timestamp (date, time, microseconds)
);

CREATE MATERIALIZED VIEW IF NOT EXISTS telemetry_can AS
  SELECT
    date + time + (microseconds * INTERVAL '1 microseconds') AS t,
    CAST(x'0CF11E05' << 3 AS BIT(29)) AS id,
    /* (CAST(speed AS BIT(8)) */
    /*   || CAST(speed >> 8 AS BIT(8)) */
    /*   || CAST( 10 * CAST(current AS INT) AS BIT(8)) */
    /*   || CAST((10 * CAST(current AS INT)) >> 8 AS BIT(8)) */
    /*   || CAST( 10 * CAST(voltage AS INT) AS BIT(8)) */
    /*   || CAST((10 * CAST(voltage AS INT)) >> 8 AS BIT(8)) */
    (set_byte(BYTEA '\x00', 0, 255 & speed)
      || set_byte(BYTEA '\x00', 0, 255 & (speed >> 8))
      || set_byte(BYTEA '\x00', 0, 255 &  (10 * CAST(current AS INT)))
      || set_byte(BYTEA '\x00', 0, 255 & ((10 * CAST(current AS INT)) >> 8))
      || set_byte(BYTEA '\x00', 0, 255 &  (10 * CAST(voltage AS INT)))
      || set_byte(BYTEA '\x00', 0, 255 & ((10 * CAST(voltage AS INT)) >> 8))
      || set_byte(BYTEA '\x00', 0, 255 & get_byte(decode(lpad(trim(both from motor_error_code), 4, '0'), 'hex'), 1))
      || set_byte(BYTEA '\x00', 0, 255 & (get_byte(decode(lpad(trim(both from motor_error_code), 4, '0'), 'hex'), 0) >> 8))
    ) AS data
  FROM telemetry_old_can_csv
    UNION
  SELECT
    date + time + (microseconds * INTERVAL '1 microseconds') AS t,
    CAST(x'0CF11F05' << 3 AS BIT(29)) AS id,
    /* (CAST(throttle AS BIT(8)) */
    /*   || CAST(40 + controller_temp AS BIT(8)) */
    /*   || CAST(30 + motor_temp AS BIT(8)) */
    (set_byte(BYTEA '\x00', 0, 255 & throttle)
      || set_byte(BYTEA '\x00', 0, 255 & (40 + controller_temp))
      || set_byte(BYTEA '\x00', 0, 255 & (30 + motor_temp))
      || decode(lpad(trim(both from controller_status), 2, '0'), 'hex')
      || decode(lpad(trim(both from switches_status), 2, '0'), 'hex')
    ) AS data
  FROM
    telemetry_old_can_csv
  WITH DATA;
