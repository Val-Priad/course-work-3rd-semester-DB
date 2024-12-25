-- 1. Пошук агентів, які уклали контракти за останній місяць,
-- із загальною сумою контрактів
SELECT agent.name || ' ' || agent.surname AS agent_name,
       COUNT(contract.id)                 AS contracts_count,
       SUM(property.price)                AS total_sum
FROM agent
         JOIN contract ON agent.id = contract.agent_id
         JOIN property ON contract.property_id = property.id
WHERE contract.start_date >= CURRENT_DATE - INTERVAL '1 month'
  and offer_type = 'buy'
GROUP BY agent.id;

-- 2. Пошук зустрічей, запланованих на завтра
SELECT appointment.date,
       property.name                      AS property_name,
       agent.name || ' ' || agent.surname AS agent_name
FROM appointment
         JOIN property ON appointment.property_id = property.id
         JOIN agent ON property.agent_id = agent.id
WHERE DATE(appointment.date) = CURRENT_DATE + INTERVAL '1 day';

-- 3. Пошук відгуків на агентів із низькими рейтингами (менше 3)
SELECT agent.name || ' ' || agent.surname AS agent_name,
       agent_review.rating,
       agent_review.comment
FROM agent_review
         JOIN agent ON agent_review.agent_id = agent.id
WHERE agent_review.rating < 3;

-- 4. Кількість об'єктів нерухомості в кожній локації
SELECT location.name      AS location_name,
       COUNT(property.id) AS property_count
FROM location
         JOIN property ON location.id = property.location
GROUP BY location.name;

-- 5. Список нерухомості з рейтингом вище середнього
SELECT property.name AS property_name,
       property.rating,
       location.name AS location_name
FROM property
         JOIN location ON property.location = location.id
WHERE property.rating > (SELECT AVG(rating) FROM property);


-- 6. Перевірка агентів із кількістю контрактів більше 5
-- (за останній місяць)
SELECT agent.name || ' ' || agent.surname AS agent_name,
       COUNT(contract.id)                 AS contract_count
FROM agent
         JOIN contract ON agent.id = contract.agent_id
WHERE contract.start_date >= CURRENT_DATE - INTERVAL '1 month'
GROUP BY agent.id
HAVING COUNT(contract.id) > 5;

-- 7. Середня ціна нерухомості за типами/плануваннями
SELECT property.type       AS property_type,
       AVG(property.price) AS avg_price,
       location.name       AS location_name
FROM property
         JOIN location ON property.location = location.id
GROUP BY property.type, location.name
ORDER BY location_name;


-- 7.2
SELECT property.layout     AS property_layout,
       AVG(property.price) AS avg_price,
       location.name       AS location_name
FROM property
         JOIN location ON property.location = location.id
GROUP BY property.layout, location.name
ORDER BY property_layout;

-- 8. Перевірка, чи є клієнти без контрактів і зустрічей
SELECT client.name || ' ' || client.surname AS client_name,
       client.phone,
       client.email
FROM client
WHERE client.id NOT IN (SELECT client_id FROM client_contract)
  AND client.id NOT IN (SELECT client_id FROM client_appointment);

-- 9. Отримання детальної інформації про завершені контракти
SELECT contract.id                               AS contract_id,
       property.name                             AS property_name,
       contract.start_date,
       contract.end_date,
       (contract.end_date - contract.start_date) AS duration
FROM contract
         JOIN property ON contract.property_id = property.id
WHERE contract.status = 'expired'
  AND property.offer_type = 'rent';

-- 10. Пошук активних контрактів із терміном завершення менше місяця
SELECT contract.id   AS contract_id,
       property.name AS property_name,
       contract.end_date
FROM contract
         JOIN property ON contract.property_id = property.id
WHERE contract.status = 'active'
  AND contract.end_date < CURRENT_DATE + INTERVAL '1 month';

-- 11. Аналіз середнього рейтингу нерухомості в різних локаціях
SELECT location.name        AS location_name,
       AVG(property.rating) AS avg_rating
FROM property
         JOIN location ON property.location = location.id
GROUP BY location.name
HAVING AVG(property.rating) IS NOT NULL;

-- 12. Перелік нерухомості, яка не має жодного відгуку але в ній жили люди
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

-- 14. Загальна кількість об'єктів нерухомості, які продаються або орендуються
SELECT COUNT(property.id)                 AS total_properties,
       agent.name || ' ' || agent.surname AS agent_name
FROM property
         JOIN agent ON property.agent_id = agent.id
WHERE property.offer_type IN ('buy', 'rent')
GROUP BY agent.id, agent.name, agent.surname
ORDER BY total_properties;


-- 15. Пошук агентів, які мають менше 3 активних контрактів за місяць
SELECT agent.name || ' ' || agent.surname AS agent_name,
       COUNT(contract.id)                 AS active_contracts
FROM agent
         JOIN contract ON agent.id = contract.agent_id
WHERE contract.status = 'active'
  AND contract.start_date >= CURRENT_DATE - INTERVAL '1 month'
GROUP BY agent.id
HAVING COUNT(contract.id) < 3;

-- 16. Список нерухомості із завершеними контрактами
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

-- 17. Перелік нерухомості, яка потребує фотографій
SELECT property.name                      AS property_name,
       owner.name || ' ' || owner.surname AS owner_name,
       owner.phone                        AS owner_phone,
       owner.email                        AS owner_email
FROM property
         LEFT JOIN property_image ON property.id = property_image.property_id
         JOIN owner_property ON property.id = owner_property.property_id
         JOIN owner ON owner_property.owner_id = owner.id
WHERE property_image.id IS NULL;

-- 18. Перелік клієнтів, які найчастіше залишають негативні відгуки
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

-- 19. Кількість клієнтів у кожному ціновому сегменті
SELECT CASE
           WHEN client.budget < 100000 THEN 'Low budget'
           WHEN client.budget BETWEEN 100000 AND 500000 THEN 'Middle budget'
           ELSE 'High budget'
           END          AS budget_segment,
       COUNT(client.id) AS client_count,
       property.layout  AS property_layout
FROM client
         LEFT JOIN contract ON client.id = contract.property_id
         LEFT JOIN property ON contract.property_id = property.id
GROUP BY budget_segment, property.layout;


-- 20. Скільки агенція заробляє з кожного агента за останній місяць
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
