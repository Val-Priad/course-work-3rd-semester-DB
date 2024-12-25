-- 17. Перелік нерухомості, яка потребує фотографій
CREATE INDEX idx_property_image_id ON property_image (property_id, id);
CREATE INDEX idx_owner_property_property_id ON owner_property (property_id);
CREATE INDEX idx_owner_property_owner_id ON owner_property (owner_id);
CREATE INDEX idx_property_id ON property (id);

ANALYZE property_image;
ANALYZE owner_property;
ANALYZE owner;
ANALYZE property;

EXPLAIN ANALYSE SELECT property.name                      AS property_name,
       owner.name || ' ' || owner.surname AS owner_name,
       owner.phone                        AS owner_phone,
       owner.email                        AS owner_email
FROM property
         LEFT JOIN property_image ON property.id = property_image.property_id
         JOIN owner_property ON property.id = owner_property.property_id
         JOIN owner ON owner_property.owner_id = owner.id
WHERE property_image.id IS NULL;

-- 5. Список нерухомості з рейтингом вище середнього
CREATE INDEX idx_property_rating_location ON property (rating, location);

ANALYSE property;


EXPLAIN ANALYSE
SELECT property.name AS property_name,
       property.rating,
       location.name AS location_name
FROM property
         JOIN location ON property.location = location.id
WHERE property.rating > (SELECT AVG(rating) FROM property);


-- 6. Перевірка агентів із кількістю контрактів більше 5
-- (за останній місяць)
CREATE INDEX idx_contract_agent_start_date_id ON contract (agent_id, start_date, id);
ANALYZE contract;

EXPLAIN ANALYSE
SELECT agent.name || ' ' || agent.surname AS agent_name,
       COUNT(contract.id)                 AS contract_count
FROM agent
         JOIN contract ON agent.id = contract.agent_id
WHERE contract.start_date >= CURRENT_DATE - INTERVAL '1 month'
GROUP BY agent.id
HAVING COUNT(contract.id) > 5;

-- 8. Перевірка, чи є клієнти без контрактів і зустрічей
CREATE INDEX idx_client_id ON client (id);
CREATE INDEX idx_client_contract_client_id ON client_contract (client_id);
CREATE INDEX idx_client_appointment_client_id ON client_appointment (client_id);

ANALYSE client;
ANALYSE client_contract;
ANALYSE client_appointment;

EXPLAIN ANALYSE
SELECT client.name || ' ' || client.surname AS client_name,
       client.phone,
       client.email
FROM client
WHERE client.id NOT IN (SELECT client_id FROM client_contract)
  AND client.id NOT IN (SELECT client_id FROM client_appointment);

-- 9. Отримання детальної інформації про завершені контракти
CREATE INDEX idx_contract_status ON contract (status, start_date, end_date);
CREATE INDEX idx_property_offer_type ON property (offer_type);

ANALYSE contract;
ANALYSE property;

EXPLAIN ANALYSE
SELECT contract.id                               AS contract_id,
       property.name                             AS property_name,
       contract.start_date,
       contract.end_date,
       (contract.end_date - contract.start_date) AS duration
FROM contract
         JOIN property ON contract.property_id = property.id
WHERE contract.status = 'expired'
  AND property.offer_type = 'rent';

-- 12. Перелік нерухомості, яка не має жодного відгуку але в ній жили люди
CREATE INDEX idx_property_id_review ON property (id);
CREATE INDEX idx_contract_property_id ON contract (property_id);
CREATE INDEX idx_client_contract_client_id ON client_contract (client_id);
CREATE INDEX idx_owner_property_property_id ON owner_property (property_id);

ANALYSE property;
ANALYSE contract;
ANALYSE client_contract;
ANALYSE owner_property;

EXPLAIN ANALYSE
SELECT property.id,
       property.name                        AS property_name,
       client.name || ' ' || client.surname AS client_name,
       client.phone,
       client.email
FROM property
         LEFT JOIN property_review ON property.id = property_review.property_id
         JOIN contract ON property.id = contract.property_id
         JOIN client_contract ON contract.id = client_contract.contract_id
         JOIN client ON client_contract.client_id = client.id
         LEFT JOIN owner_property ON property.id = owner_property.property_id
         LEFT JOIN owner ON owner_property.owner_id = owner.id
WHERE property_review.id IS NULL;

-- 13. Клієнти, які залишили більше двох відгуків будь де
CREATE INDEX idx_client_id_reviews ON client (id);
CREATE INDEX idx_agent_review_client_id ON agent_review (client_id);
CREATE INDEX idx_owner_review_client_id ON owner_review (client_id);
CREATE INDEX idx_property_review_client_id ON property_review (client_id);

ANALYSE client;
ANALYSE agent_review;
ANALYSE owner_review;
ANALYSE property_review;

EXPLAIN ANALYSE
SELECT client.id                            AS client_id,
       client.name || ' ' || client.surname AS client_name,
       client.email,
       COUNT(*)                             AS total_reviews
FROM client
         LEFT JOIN agent_review ON client.id = agent_review.client_id
         LEFT JOIN owner_review ON client.id = owner_review.client_id
         LEFT JOIN property_review ON client.id = property_review.client_id
GROUP BY client.id, client.name, client.surname, client.email
HAVING COUNT(*) > 2;

-- 16. Список нерухомості із завершеними контрактами
CREATE INDEX idx_property_id_contract_status ON contract (property_id, status);
CREATE INDEX idx_contract_status_expired ON contract (status);

ANALYSE contract;

EXPLAIN ANALYSE
SELECT property.id        AS property_id,
       property.name      AS property_name,
       COUNT(contract.id) AS completed_contracts
FROM property
         JOIN contract ON property.id = contract.property_id
WHERE property.id NOT IN (SELECT property_id
                          FROM contract
                          WHERE status = 'active')
  AND contract.status = 'expired'
GROUP BY property.id, property.name
HAVING COUNT(contract.id) > 0;

-- 18. Перелік клієнтів, які найчастіше залишають негативні відгуки
CREATE INDEX idx_client_negative_reviews ON client (id);
CREATE INDEX idx_agent_review_rating_client ON agent_review (client_id, rating);
CREATE INDEX idx_owner_review_rating_client ON owner_review (client_id, rating);
CREATE INDEX idx_property_review_rating_client ON property_review (client_id, rating);

ANALYSE client;
ANALYSE agent_review;
ANALYSE owner_review;
ANALYSE property_review;

EXPLAIN ANALYSE
SELECT client.id                            AS client_id,
       client.name || ' ' || client.surname AS client_name,
       client.email                         AS client_email,
       COUNT(*)                             AS negative_reviews_count
FROM client
         LEFT JOIN (SELECT client_id, rating
                    FROM agent_review
                    WHERE rating < 3
                    UNION ALL
                    SELECT client_id, rating
                    FROM owner_review
                    WHERE rating < 3
                    UNION ALL
                    SELECT client_id, rating
                    FROM property_review
                    WHERE rating < 3) AS negative_reviews
                   ON client.id = negative_reviews.client_id
GROUP BY client.id, client.name, client.surname, client.email
HAVING COUNT(negative_reviews.rating) > 0
ORDER BY negative_reviews_count DESC;

-- 20. Скільки агенція заробляє з кожного агента за останній місяць
CREATE INDEX idx_contract_start_date_status ON contract (start_date, status);
CREATE INDEX idx_property_price ON property (id, price);
CREATE INDEX idx_agent_commission_rate ON agent (id, commission_rate);

ANALYSE contract;
ANALYSE property;
ANALYSE agent;

EXPLAIN ANALYSE
SELECT agent.id                           AS agent_id,
       agent.name || ' ' || agent.surname AS agent_name,
       SUM(property.price * (agent.commission_rate / 100) *
           0.5)                           AS agency_earnings
FROM contract
         JOIN property ON contract.property_id = property.id
         JOIN agent ON contract.agent_id = agent.id
WHERE contract.start_date >= CURRENT_DATE - INTERVAL '1 month'
  AND contract.status = 'active'
GROUP BY agent.id, agent.name, agent.surname
ORDER BY agency_earnings DESC;
