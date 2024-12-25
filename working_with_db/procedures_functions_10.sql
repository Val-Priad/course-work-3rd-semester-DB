-- 1. Функція для розрахунку середнього рейтингу агента
CREATE OR REPLACE FUNCTION calculate_agent_avg_rating(id_agent INT)
    RETURNS NUMERIC AS
$$
BEGIN
    RETURN (SELECT AVG(rating)
            FROM agent_review
            WHERE agent_id = id_agent);
END;
$$ LANGUAGE plpgsql;

SELECT calculate_agent_avg_rating(2);

-- 1.2 Функція для розрахунку середнього рейтингу власника
CREATE OR REPLACE FUNCTION calculate_owner_avg_rating(id_owner INT)
    RETURNS NUMERIC AS
$$
BEGIN
    RETURN (SELECT AVG(rating)
            FROM owner_review
            WHERE owner_id = id_owner);
END;
$$ LANGUAGE plpgsql;

SELECT calculate_owner_avg_rating(2);

-- 1.3 Функція для розрахунку середнього рейтингу нерухомості
CREATE OR REPLACE FUNCTION calculate_property_avg_rating(id_property INT)
    RETURNS NUMERIC AS
$$
BEGIN
    RETURN (SELECT AVG(rating)
            FROM property_review
            WHERE property_id = id_property);
END;
$$ LANGUAGE plpgsql;

SELECT calculate_property_avg_rating(1);



-- 2. Процедура, яка вираховує рейтинг для кожного агента і власника
-- і встановлює його.
CREATE OR REPLACE PROCEDURE update_all_ratings()
    LANGUAGE plpgsql AS
$$
BEGIN
    UPDATE agent
    SET rating = (SELECT AVG(rating)
                  FROM agent_review
                  WHERE agent_review.agent_id = agent.id);

    UPDATE owner
    SET rating = (SELECT AVG(rating)
                  FROM owner_review
                  WHERE owner_review.owner_id = owner.id);

    UPDATE property
    SET rating = (SELECT AVG(rating)
                  FROM property_review
                  WHERE property_review.property_id = property.id);
END;
$$;

CALL update_all_ratings();

SELECT *
FROM owner
LIMIT 50;
SELECT *
FROM agent
LIMIT 50;
SELECT *
FROM property
LIMIT 50;
SELECT *
FROM agent
WHERE rating is not null
LIMIT 50;
SELECT *
FROM owner
WHERE rating is not null
LIMIT 50;
SELECT *
FROM property
WHERE rating is not null
LIMIT 50;

-- 3. Процедура для оновлення статусу контракту, якщо термін дії закінчився
CREATE OR REPLACE PROCEDURE update_expired_contracts()
    LANGUAGE plpgsql AS
$$
BEGIN
    UPDATE contract
    SET status = 'expired'
    WHERE end_date < CURRENT_DATE
      AND status = 'active';
END;
$$;

SELECT MAX(id)
FROM contract;

INSERT INTO contract (id, property_id, agent_id, start_date, end_date, terms,
                      status)
VALUES (103, 1, '2024-01-01', '2024-12-01', 'testing_procedure', 'active');

SELECT *
FROM contract
WHERE end_date < CURRENT_DATE;
CALL update_expired_contracts();

-- 4. Функція для отримання доступних об'єктів нерухомості в певній локації
CREATE OR REPLACE FUNCTION get_available_properties(location_id INT)
    RETURNS TABLE
            (
                property_id INT,
                name        VARCHAR,
                price       NUMERIC
            )
AS
$$
BEGIN
    RETURN QUERY
        SELECT p.id, p.name, p.price
        FROM property p
        WHERE location = location_id;
END;
$$ LANGUAGE plpgsql;

SELECT loc.id,
       loc.name        AS location_name,
       COUNT(prop.id)  AS property_count,
       SUM(prop.price) AS total_price
FROM location loc
         JOIN
     property prop
     ON
         loc.id = prop.location
GROUP BY loc.name, loc.id
HAVING COUNT(prop.id) > 1;


SELECT get_available_properties(51);

-- 5. Процедура для створення нового клієнта
CREATE OR REPLACE PROCEDURE create_new_client(
    client_name VARCHAR,
    client_surname VARCHAR,
    client_email VARCHAR,
    client_phone VARCHAR,
    client_budget NUMERIC,
    preferred_location_id INTEGER DEFAULT NULL,
    client_info TEXT DEFAULT NULL
)
    LANGUAGE plpgsql AS
$$
BEGIN
    IF client_name IS NULL OR client_email IS NULL OR client_phone IS NULL THEN
        RAISE EXCEPTION 'Name, email, and phone are required fields.';
    END IF;

    IF EXISTS (SELECT 1
               FROM client
               WHERE email = client_email
                  OR phone = client_phone) THEN
        RAISE EXCEPTION 'Client with this email or phone already exists.';
    END IF;

    IF preferred_location_id IS NOT NULL AND
       NOT EXISTS (SELECT 1 FROM location WHERE id = preferred_location_id) THEN
        RAISE EXCEPTION 'Preferred location with ID % does not exist.', preferred_location_id;
    END IF;

    INSERT INTO client (name, surname, email, phone, budget, preferred_location,
                        info)
    VALUES (client_name, client_surname, client_email, client_phone,
            client_budget, preferred_location_id, client_info);

    RAISE NOTICE 'Client % % has been successfully created.', client_name, client_surname;
END;
$$;

CALL create_new_client(
        'John',
        'Doe',
        'john.doe@example.com',
        '+123456789',
        500000.00,
        1,
        'Looking for an apartment in the city center.'
     );

SELECT *
FROM client
WHERE email = 'john.doe@example.com';

-- 6. функція для перевірки, чи доступний агент для призначення зустрічі
CREATE OR REPLACE FUNCTION is_agent_available(property_id INT, desired_time TIMESTAMP)
    RETURNS BOOLEAN AS
$$
BEGIN
    RETURN NOT EXISTS (SELECT 1
                       FROM appointment a
                                JOIN property p ON a.property_id = p.id
                       WHERE p.id = $1
                         AND a.date BETWEEN desired_time - INTERVAL '1.5 hours' AND desired_time + INTERVAL '1.5 hours');
END;
$$ LANGUAGE plpgsql;

SELECT is_agent_available(69, '2024-02-02 22:00:00');
SELECT is_agent_available(69, '2024-02-02 20:30:00');

-- 7. Процедура для призначення зустрічі
CREATE OR REPLACE PROCEDURE create_appointment(
    id_property INT,
    client_ids INT[], -- Масив ID клієнтів
    desired_time TIMESTAMP,
    appointment_notes TEXT
)
    LANGUAGE plpgsql AS
$$
DECLARE
    id_agent       INT;
    appointment_id INT;
    owner_id       INT;
    client_id      INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM property WHERE id = id_property) THEN
        RAISE EXCEPTION 'Property with ID % does not exist.', id_property;
    END IF;

    IF desired_time <= CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'Desired time for the appointment (%s) must be in the future.', desired_time;
    END IF;

    SELECT p.agent_id
    INTO id_agent
    FROM property p
    WHERE p.id = id_property;

    IF id_agent IS NULL THEN
        RAISE EXCEPTION 'Property with ID % is not assigned to any agent.', id_property;
    END IF;

    IF NOT is_agent_available(id_property, desired_time) THEN
        RAISE EXCEPTION 'Agent for property with ID % is not available at the requested time.', id_property;
    END IF;

    INSERT INTO appointment (property_id, date, status, notes)
    VALUES (id_property, desired_time, 'planned', appointment_notes)
    RETURNING id INTO appointment_id;

    FOREACH client_id IN ARRAY client_ids LOOP
            INSERT INTO client_appointment (client_id, appointment_id)
            VALUES (client_id, appointment_id);
        END LOOP;

    SELECT op.owner_id
    INTO owner_id
    FROM owner_property op
    WHERE op.property_id = id_property
    LIMIT 1;

    IF owner_id IS NOT NULL THEN
        INSERT INTO owner_appointment (appointment_id, owner_id)
        VALUES (appointment_id, owner_id);
    END IF;

    RAISE NOTICE 'Appointment successfully created for property ID % at % for clients: %.', id_property, desired_time, client_ids;
END;
$$;



CALL create_appointment(1, ARRAY[1, 2, 3], '2024-12-29 10:52:17', '');

SELECT * FROM appointment WHERE date = '2024-12-29 10:52:17';
SELECT * FROM client_appointment WHERE appointment_id = 439;
SELECT * FROM owner_appointment WHERE appointment_id = 439;


-- 8. функція для отримання топ-3 найкращих агентів за рейтингом
CREATE OR REPLACE FUNCTION get_top_agents(limit_count INT DEFAULT 3)
    RETURNS TABLE
            (
                agent_id     INT,
                agent_name   VARCHAR,
                agent_rating NUMERIC
            )
AS
$$
BEGIN
    RETURN QUERY
        SELECT id, name, rating
        FROM agent
        WHERE rating IS NOT NULL
        ORDER BY rating DESC
        LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

SELECT get_top_agents();

-- 9. процедура для автоматичного закриття прострочених зустрічей
CREATE OR REPLACE PROCEDURE auto_close_past_appointments()
    LANGUAGE plpgsql AS
$$
BEGIN
    UPDATE appointment
    SET status = 'canceled'
    WHERE status = 'planned'
      AND date < CURRENT_TIMESTAMP;

    UPDATE appointment
    SET status = 'finished'
    WHERE status = 'in_progress'
      AND date < CURRENT_TIMESTAMP;

    RAISE NOTICE 'Past appointments have been closed.';
END;
$$;

INSERT INTO appointment (property_id, date, status)
VALUES (94, '2024-05-18 08:38:13', 'planned');
INSERT INTO appointment (property_id, date, status)
VALUES (94, current_timestamp - interval '2 hours', 'in_progress');

SELECT *
FROM appointment
WHERE property_id = 94;
SELECT *
FROM appointment
WHERE status IN ('planned', 'in_progress')
  AND DATE < CURRENT_TIMESTAMP;

CALL auto_close_past_appointments();

-- 10. Функція для розрахунку загальної комісії рієлтора за активними контрактами
CREATE OR REPLACE FUNCTION calculate_agent_commission(id_agent INT)
    RETURNS NUMERIC AS
$$
BEGIN
    RETURN (SELECT SUM(p.price * (a.commission_rate / 100))
            FROM contract c
                     JOIN property p ON c.property_id = p.id
                     JOIN agent a ON c.agent_id = a.id
            WHERE c.agent_id = id_agent
              AND c.status = 'active');
END;
$$ LANGUAGE plpgsql;

SELECT calculate_agent_commission(1);



DROP FUNCTION IF EXISTS calculate_agent_avg_rating;
DROP FUNCTION IF EXISTS calculate_owner_avg_rating;
DROP PROCEDURE IF EXISTS update_all_ratings();
DROP PROCEDURE IF EXISTS update_expired_contracts();
DROP FUNCTION IF EXISTS get_available_properties(location_id INT);
DROP FUNCTION IF EXISTS create_new_client(client_name VARCHAR,
                                          client_surname VARCHAR,
                                          client_email VARCHAR,
                                          client_phone VARCHAR,
                                          client_budget NUMERIC,
                                          preferred_location_id INTEGER,
                                          client_info TEXT);
DROP FUNCTION IF EXISTS is_agent_available;
DROP PROCEDURE IF EXISTS create_appointment(property_id INT,
                                            desired_time TIMESTAMP,
                                            appointment_notes TEXT);
DROP FUNCTION IF EXISTS get_top_agents(limit_count INT);
DROP FUNCTION IF EXISTS auto_close_past_appointments();
DROP FUNCTION IF EXISTS create_appointment(property_id INT,
                                           desired_time TIMESTAMP,
                                           appointment_notes TEXT);
DROP FUNCTION IF EXISTS create_appointment(id_property INT, client_ids INT[],
                                           desired_time TIMESTAMP,
                                           appointment_notes TEXT);





