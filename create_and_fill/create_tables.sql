CREATE TYPE appointment_status AS ENUM ('planned', 'in_progress', 'canceled', 'finished');
CREATE TYPE property_type AS ENUM ('apartment', 'house');
CREATE TYPE property_layout AS ENUM ('1+kk', '1+1', '2+kk', '2+1', '3+kk', '3+1', '4+kk', '4+1', '5+kk', '5+1', '6 and more');
CREATE TYPE property_offer_type AS ENUM ('buy', 'rent');
CREATE TYPE property_condition AS ENUM ('shell and core', 'white shell', 'furnished and equipped', 'open plan', 'dilapidated condition', 'specially equipped');
CREATE TYPE energy_consumption_class AS ENUM ('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H');
CREATE TYPE contract_status AS ENUM ('active', 'terminated', 'expired');

CREATE TABLE location
(
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    latitude        NUMERIC(9, 6) CHECK (latitude BETWEEN -90 AND 90),
    longitude       NUMERIC(9, 6) CHECK (longitude BETWEEN -180 AND 180),
    parent_location INTEGER REFERENCES location (id) ON DELETE CASCADE
);

CREATE TABLE client
(
    id                 SERIAL PRIMARY KEY,
    name               VARCHAR(100)        NOT NULL,
    surname            VARCHAR(100),
    email              VARCHAR(100) UNIQUE NOT NULL,
    phone              VARCHAR(15) UNIQUE  NOT NULL,
    preferred_location INTEGER             REFERENCES location (id) ON DELETE SET NULL,
    budget             NUMERIC(12, 2) CHECK (budget >= 0),
    info               TEXT
);

CREATE TABLE owner
(
    id      SERIAL PRIMARY KEY,
    name    VARCHAR(100)        NOT NULL,
    surname VARCHAR(100),
    email   VARCHAR(100) UNIQUE NOT NULL,
    phone   VARCHAR(15) UNIQUE  NOT NULL,
    rating  NUMERIC(3, 1) CHECK (rating BETWEEN 0 AND 5)
);

CREATE TABLE agent
(
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(100)        NOT NULL,
    surname         VARCHAR(100),
    email           VARCHAR(100) UNIQUE NOT NULL,
    phone           VARCHAR(15) UNIQUE  NOT NULL,
    rating          NUMERIC(2, 1) CHECK (rating BETWEEN 0 AND 5),
    commission_rate NUMERIC(5, 2) CHECK (commission_rate >= 0),
    info            TEXT
);

CREATE TABLE property
(
    id                 SERIAL PRIMARY KEY,
    name               VARCHAR(100) NOT NULL,
    description        TEXT,
    price              NUMERIC(12, 2) CHECK (price >= 0),
    type               property_type,
    layout             property_layout,
    area               NUMERIC(10, 2) CHECK (area > 0),
    offer_type         property_offer_type,
    condition          property_condition,
    energy_consumption energy_consumption_class,
    rating             NUMERIC(2, 1) CHECK (rating BETWEEN 0 AND 5),
    location           INTEGER      REFERENCES location (id) ON DELETE SET NULL,
    agent_id           INTEGER      REFERENCES agent (id) ON DELETE SET NULL
);

CREATE TABLE agent_review
(
    id         SERIAL PRIMARY KEY,
    client_id  INTEGER REFERENCES client (id) ON DELETE CASCADE,
    agent_id   INTEGER REFERENCES agent (id) ON DELETE CASCADE,
    rating     NUMERIC(2, 1) CHECK (rating BETWEEN 0 AND 5),
    comment    TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE owner_review
(
    id         SERIAL PRIMARY KEY,
    client_id  INTEGER REFERENCES client (id) ON DELETE CASCADE,
    owner_id   INTEGER REFERENCES owner (id) ON DELETE CASCADE,
    rating     NUMERIC(2, 1) CHECK (rating BETWEEN 0 AND 5),
    comment    TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE property_review
(
    id          SERIAL PRIMARY KEY,
    client_id   INTEGER REFERENCES client (id) ON DELETE CASCADE,
    property_id INTEGER REFERENCES property (id) ON DELETE CASCADE,
    rating      NUMERIC(2, 1) CHECK (rating BETWEEN 0 AND 5),
    comment     TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE appointment
(
    id          SERIAL PRIMARY KEY,
    property_id INTEGER REFERENCES property (id) ON DELETE CASCADE,
    date        TIMESTAMP NOT NULL,
    status      appointment_status,
    notes       TEXT
);

CREATE TABLE property_image
(
    id          SERIAL PRIMARY KEY,
    property_id INTEGER REFERENCES property (id) ON DELETE CASCADE,
    image_url   TEXT NOT NULL,
    description TEXT,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE contract
(
    id          SERIAL PRIMARY KEY,
    property_id INTEGER REFERENCES property (id) ON DELETE CASCADE,
    agent_id    INTEGER REFERENCES agent (id) ON DELETE SET NULL,
    start_date  DATE    NOT NULL,
    end_date    DATE CHECK (end_date IS NULL OR end_date > start_date),
    terms       TEXT,
    status      contract_status
);

CREATE TABLE client_contract
(
    client_id   INTEGER REFERENCES client (id) ON DELETE CASCADE,
    contract_id INTEGER REFERENCES contract (id) ON DELETE CASCADE,
    PRIMARY KEY (client_id, contract_id)
);

CREATE TABLE client_appointment
(
    client_id      INTEGER REFERENCES client (id) ON DELETE CASCADE,
    appointment_id INTEGER REFERENCES appointment (id) ON DELETE CASCADE,
    PRIMARY KEY (client_id, appointment_id)
);

CREATE TABLE owner_contract
(
    owner_id    INTEGER REFERENCES owner (id) ON DELETE CASCADE,
    contract_id INTEGER REFERENCES contract (id) ON DELETE CASCADE,
    PRIMARY KEY (owner_id, contract_id)
);

CREATE TABLE owner_property
(
    owner_id    INTEGER REFERENCES owner (id) ON DELETE CASCADE,
    property_id INTEGER REFERENCES property (id) ON DELETE CASCADE,
    PRIMARY KEY (owner_id, property_id)
);

CREATE TABLE owner_appointment
(
    appointment_id INTEGER REFERENCES appointment (id) ON DELETE CASCADE,
    owner_id       INTEGER REFERENCES owner (id) ON DELETE CASCADE,
    PRIMARY KEY (appointment_id, owner_id)
);


DROP TABLE IF EXISTS owner_appointment CASCADE;
DROP TABLE IF EXISTS contract_owner CASCADE;
DROP TABLE IF EXISTS appointment_client CASCADE;
DROP TABLE IF EXISTS appointment_owner CASCADE;
DROP TABLE IF EXISTS owner_property CASCADE;
DROP TABLE IF EXISTS owner_contract CASCADE;
DROP TABLE IF EXISTS client_appointment CASCADE;
DROP TABLE IF EXISTS client_contract CASCADE;
DROP TABLE IF EXISTS contract CASCADE;
DROP TABLE IF EXISTS property_image CASCADE;
DROP TABLE IF EXISTS appointment CASCADE;
DROP TABLE IF EXISTS property_review CASCADE;
DROP TABLE IF EXISTS owner_review CASCADE;
DROP TABLE IF EXISTS agent_review CASCADE;
DROP TABLE IF EXISTS property CASCADE;
DROP TABLE IF EXISTS agent CASCADE;
DROP TABLE IF EXISTS owner CASCADE;
DROP TABLE IF EXISTS client CASCADE;
DROP TABLE IF EXISTS location CASCADE;
DROP TYPE IF EXISTS contract_status;
DROP TYPE IF EXISTS energy_consumption_class;
DROP TYPE IF EXISTS property_condition;
DROP TYPE IF EXISTS property_offer_type;
DROP TYPE IF EXISTS property_layout;
DROP TYPE IF EXISTS property_type;
DROP TYPE IF EXISTS appointment_status;



