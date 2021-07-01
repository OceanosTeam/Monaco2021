CREATE TABLE raw_can (
	t timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
	id bit(29),
	data bytea,
	PRIMARY KEY (t, id)
);

CREATE INDEX raw_can_id ON raw_can (id);
