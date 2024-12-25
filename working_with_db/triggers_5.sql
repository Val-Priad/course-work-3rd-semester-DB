-- 1. Тригер для автоматичного оновлення рейтингу агента
CREATE OR REPLACE FUNCTION update_agent_rating_trigger()
    RETURNS TRIGGER AS
$$
BEGIN
    UPDATE agent
    SET rating = calculate_agent_avg_rating(NEW.agent_id)
    WHERE id = NEW.agent_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_agent_review_insert
    AFTER INSERT OR UPDATE OR DELETE
    ON agent_review
    FOR EACH ROW
EXECUTE FUNCTION update_agent_rating_trigger();

SELECT calculate_agent_avg_rating(2);


INSERT INTO agent_review (client_id, agent_id, rating)
VALUES (57, 2, 5);

--1.2 Тригер для автоматичного оновлення рейтингу власника
CREATE OR REPLACE FUNCTION update_owner_rating_trigger()
    RETURNS TRIGGER AS
$$
BEGIN
    UPDATE owner
    SET rating = (SELECT AVG(rating)
                  FROM owner_review
                  WHERE owner_id = COALESCE(NEW.owner_id, OLD.owner_id))
    WHERE id = COALESCE(NEW.owner_id, OLD.owner_id);

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_owner_review_modification
    AFTER INSERT OR UPDATE OR DELETE
    ON owner_review
    FOR EACH ROW
EXECUTE FUNCTION update_owner_rating_trigger();

INSERT INTO owner_review (client_id, owner_id, rating, comment)
VALUES (1, 2, 4.0, 'Good owner to work with.');

SELECT calculate_owner_avg_rating(2);


-- 1.3 Тригер для автоматичного оновлення рейтингу нерухомості
CREATE OR REPLACE FUNCTION update_property_rating_trigger()
    RETURNS TRIGGER AS
$$
BEGIN

    UPDATE property
    SET rating = calculate_property_avg_rating(NEW.property_id)
    WHERE id = NEW.property_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_property_review_insert
    AFTER INSERT OR UPDATE OR DELETE
    ON property_review
    FOR EACH ROW
EXECUTE FUNCTION update_property_rating_trigger();

INSERT INTO property_review (client_id, property_id, rating, comment)
VALUES (1, 1, 4.5, 'Great property.');

DELETE
FROM property_review
WHERE id = 23;

SELECT calculate_property_avg_rating(1);

-- 2. Тригери, що роблять неможливим додання коментарів тими людьми,
-- що не мали справу з агентом, нерухомістю чи власниками
-- 2.1
CREATE OR REPLACE FUNCTION validate_agent_review()
    RETURNS TRIGGER AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1
                   FROM appointment a
                            JOIN client_appointment ca
                                 ON a.id = ca.appointment_id
                            JOIN property p ON a.property_id = p.id
                   WHERE ca.client_id = NEW.client_id
                     AND p.agent_id = NEW.agent_id) THEN
        RAISE EXCEPTION 'Client with ID % cannot leave a review for agent with ID % because they have not worked together.', NEW.client_id, NEW.agent_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_agent_review_insert
    BEFORE INSERT
    ON agent_review
    FOR EACH ROW
EXECUTE FUNCTION validate_agent_review();

INSERT INTO appointment (property_id, date, status, notes)
VALUES (1, '2024-12-29 10:00:00', 'finished', 'Client met agent');

INSERT INTO client_appointment (client_id, appointment_id)
VALUES (1, 1);

INSERT INTO agent_review (client_id, agent_id, rating, comment)
VALUES (1, 11, 5, 'Excellent agent!');

INSERT INTO agent_review (client_id, agent_id, rating, comment)
VALUES (1, 10, 1, 'Really bad agent!');


-- 2.2
CREATE OR REPLACE FUNCTION validate_property_review()
    RETURNS TRIGGER AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1
                   FROM contract c
                            JOIN client_contract cc ON c.id = cc.contract_id
                   WHERE cc.client_id = NEW.client_id
                     AND c.property_id = NEW.property_id) THEN
        RAISE EXCEPTION 'Client with ID % cannot leave a review for property with ID % because they have not been associated with a contract for this property.', NEW.client_id, NEW.property_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_property_review_insert
    BEFORE INSERT
    ON property_review
    FOR EACH ROW
EXECUTE FUNCTION validate_property_review();

INSERT INTO contract (property_id, agent_id, start_date, end_date, terms,
                      status)
VALUES (1, 11, '2024-01-01', '2024-12-31', 'Test', 'active');

INSERT INTO client_contract (client_id, contract_id)
VALUES (1, 110);

INSERT INTO property_review (client_id, property_id, rating, comment)
VALUES (1, 1, 4, 'Nice property!');

INSERT INTO property_review (client_id, property_id, rating, comment)
VALUES (1, 2, 1, 'Bad property!');


-- 2.3
CREATE OR REPLACE FUNCTION validate_owner_review()
    RETURNS TRIGGER AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1
                   FROM contract c
                            JOIN owner_contract oc ON c.id = oc.contract_id
                            JOIN client_contract cc ON c.id = cc.contract_id
                   WHERE cc.client_id = NEW.client_id
                     AND oc.owner_id = NEW.owner_id) THEN
        RAISE EXCEPTION 'Client with ID % cannot leave a review for owner with ID % because they have not worked together.', NEW.client_id, NEW.owner_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_owner_review_insert
    BEFORE INSERT
    ON owner_review
    FOR EACH ROW
EXECUTE FUNCTION validate_owner_review();

INSERT INTO owner_contract (owner_id, contract_id)
VALUES (1, 1);

INSERT INTO owner_review (client_id, owner_id, rating, comment)
VALUES (1, 1, 5, 'Friendly owner!');

INSERT INTO owner_review (client_id, owner_id, rating, comment)
VALUES (1, 2, 1, 'Evil owner!');


-- 3. Тригер для запобігання видаленню клієнтів із активними контрактами
CREATE OR REPLACE FUNCTION prevent_client_deletion_with_active_contracts()
    RETURNS TRIGGER AS
$$
BEGIN
    IF EXISTS (SELECT 1
               FROM client_contract cc
                        JOIN contract c ON cc.contract_id = c.id
               WHERE cc.client_id = OLD.id
                 AND c.status = 'active') THEN
        RAISE EXCEPTION 'Client with ID % cannot be deleted because they have active contracts.', OLD.id;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_client_delete
    BEFORE DELETE
    ON client
    FOR EACH ROW
EXECUTE FUNCTION prevent_client_deletion_with_active_contracts();

SELECT id, property_id, cl.client_id, end_date, status
FROM contract
         JOIN public.client_contract cl ON contract.id = cl.contract_id
WHERE status = 'active';
DELETE
FROM client
WHERE id = 70;


-- 4. Тригер для автоматичного встановлення стандартного опису нерухомості, якщо його не вказано
CREATE OR REPLACE FUNCTION generate_property_description()
    RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.description IS NULL OR TRIM(NEW.description) = '' THEN
        NEW.description =
                'Property: ' || NEW.name || ', ' ||
                'Type: ' || NEW.type || ', ' ||
                'Layout: ' || NEW.layout || ', ' ||
                'Area: ' || NEW.area || ' sq.m, ' ||
                'Offer: ' || NEW.offer_type || ', ' ||
                'Condition: ' || NEW.condition || ', ' ||
                'Energy Consumption: ' || NEW.energy_consumption || ', ' ||
                'Price: ' || NEW.price || ' USD';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_property_insert
    BEFORE INSERT
    ON property
    FOR EACH ROW
EXECUTE FUNCTION generate_property_description();

INSERT INTO property (name, description,
                      price, type,
                      layout, area,
                      offer_type, condition,
                      energy_consumption, location,
                      agent_id)
VALUES ('Luxury Apartment',
        '',
        200000.00,
        'apartment',
        '3+1',
        120.50,
        'buy',
        'furnished and equipped',
        'A',
        1,
        1);

SELECT name, description
FROM property
WHERE name = 'Luxury Apartment';


-- 5. Тригер, що регулює зустрічі клієнта/власника/агента
-- 5.1 клієнт
CREATE OR REPLACE FUNCTION prevent_duplicate_client_appointments()
    RETURNS TRIGGER AS
$$
BEGIN
    IF EXISTS (SELECT 1
               FROM appointment a
                        JOIN client_appointment ca ON a.id = ca.appointment_id
               WHERE ca.client_id = NEW.client_id
                 AND a.date = (SELECT date
                               FROM appointment
                               WHERE id = NEW.appointment_id)
                 AND a.property_id != (SELECT property_id
                                       FROM appointment
                                       WHERE id = NEW.appointment_id)) THEN
        RAISE EXCEPTION 'Client with ID % already has an appointment at the same time for another property.', NEW.client_id;
    END IF;

    IF EXISTS (SELECT 1
               FROM appointment a
                        JOIN client_appointment ca ON a.id = ca.appointment_id
               WHERE ca.client_id = NEW.client_id
                 AND a.property_id = (SELECT property_id
                                      FROM appointment
                                      WHERE id = NEW.appointment_id)
                 AND DATE(a.date) = DATE((SELECT date
                                          FROM appointment
                                          WHERE id = NEW.appointment_id))) THEN
        RAISE EXCEPTION 'Client with ID % already has an appointment for property ID % on the same day.', NEW.client_id, (SELECT property_id
                                                                                                                          FROM appointment
                                                                                                                          WHERE id = NEW.appointment_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_client_appointment_insert
    BEFORE INSERT
    ON client_appointment
    FOR EACH ROW
EXECUTE FUNCTION prevent_duplicate_client_appointments();

INSERT INTO appointment (property_id, date, status, notes)
VALUES (2, '2024-12-29 10:00:00', 'planned', 'Conflict appointment');

INSERT INTO client_appointment (client_id, appointment_id)
VALUES (1, 404);

INSERT INTO appointment (property_id, date, status, notes)
VALUES (2, '2024-12-29 10:00:00', 'planned', 'Conflict appointment');

INSERT INTO client_appointment (client_id, appointment_id)
VALUES (1, 404);



-- 5.2 Власника
CREATE OR REPLACE FUNCTION prevent_duplicate_owner_appointments()
    RETURNS TRIGGER AS
$$
BEGIN
    IF EXISTS (SELECT 1
               FROM appointment a
                        JOIN owner_appointment oa ON a.id = oa.appointment_id
               WHERE oa.owner_id = NEW.owner_id
                 AND a.date = (SELECT date
                               FROM appointment
                               WHERE id = NEW.appointment_id)
                 AND a.property_id != (SELECT property_id
                                       FROM appointment
                                       WHERE id = NEW.appointment_id)) THEN
        RAISE EXCEPTION 'Owner with ID % already has an appointment at the same time for another property.', NEW.owner_id;
    END IF;

    IF EXISTS (SELECT 1
               FROM appointment a
                        JOIN owner_appointment oa ON a.id = oa.appointment_id
               WHERE oa.owner_id = NEW.owner_id
                 AND a.property_id = (SELECT property_id
                                      FROM appointment
                                      WHERE id = NEW.appointment_id)
                 AND DATE(a.date) = DATE((SELECT date
                                          FROM appointment
                                          WHERE id = NEW.appointment_id))) THEN
        RAISE EXCEPTION 'Owner with ID % already has an appointment for property ID % on the same day.', NEW.owner_id, (SELECT property_id
                                                                                                                        FROM appointment
                                                                                                                        WHERE id = NEW.appointment_id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER before_owner_appointment_insert
    BEFORE INSERT
    ON owner_appointment
    FOR EACH ROW
EXECUTE FUNCTION prevent_duplicate_owner_appointments();

INSERT INTO appointment (property_id, date, status, notes)
VALUES (3, '2024-12-31 09:00:00', 'planned', 'Conflict appointment.');

INSERT INTO owner_appointment (owner_id, appointment_id)
VALUES (1, 449);

INSERT INTO appointment (property_id, date, status, notes)
VALUES (1, '2024-12-31 11:00:00', 'planned', 'Same day conflict.');

INSERT INTO owner_appointment (owner_id, appointment_id)
VALUES (1, 449);


-- 5.3 агента
CREATE OR REPLACE FUNCTION prevent_duplicate_agent_appointments()
    RETURNS TRIGGER AS
$$
DECLARE
    agent_id_from_property INT;
BEGIN
    -- Retrieve the agent_id associated with the property in the NEW record
    SELECT agent_id INTO agent_id_from_property
    FROM property
    WHERE id = NEW.property_id;

    -- Ensure the retrieved agent_id is not NULL
    IF agent_id_from_property IS NULL THEN
        RAISE EXCEPTION 'Property ID % in appointment does not have an assigned agent.', NEW.property_id;
    END IF;

    -- Check for conflicts: agent has another appointment at the same time for a different property
    IF EXISTS (
        SELECT 1
        FROM appointment a
                 JOIN property p ON a.property_id = p.id
        WHERE p.agent_id = agent_id_from_property
          AND a.date = NEW.date
          AND a.property_id != NEW.property_id
    ) THEN
        RAISE EXCEPTION 'Agent with ID % already has an appointment at the same time for another property.', agent_id_from_property;
    END IF;

    -- Check for conflicts: agent has another appointment on the same day for the same property
    IF EXISTS (
        SELECT 1
        FROM appointment a
                 JOIN property p ON a.property_id = p.id
        WHERE p.agent_id = agent_id_from_property
          AND a.property_id = NEW.property_id
          AND DATE(a.date) = DATE(NEW.date)
    ) THEN
        RAISE EXCEPTION 'Agent with ID % already has an appointment for property ID % on the same day.', agent_id_from_property, NEW.property_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_agent_appointment_insert
    BEFORE INSERT
    ON appointment
    FOR EACH ROW
EXECUTE FUNCTION prevent_duplicate_agent_appointments();


INSERT INTO appointment (property_id, date, status, notes)
VALUES (45, '2024-12-29 10:00:00', 'planned', 'First appointment.');

INSERT INTO appointment (property_id, date, status, notes)
VALUES (103, '2024-12-29 10:00:00', 'planned', 'Time conflict.');

INSERT INTO appointment (property_id, date, status, notes)
VALUES (45, '2024-12-29 12:00:00', 'planned', 'Same day conflict.');

