CREATE VIEW available_properties AS
SELECT id, name, price, layout, location, offer_type
FROM property
WHERE id NOT IN (SELECT property_id
                 FROM contract
                 WHERE status = 'active');

SELECT * FROM available_properties;

CREATE VIEW client_agent_reviews AS
SELECT client.name    AS client_name,
       client.surname AS client_surname,
       agent.name     AS agent_name,
       agent.surname  AS agent_surname,
       agent_review.rating,
       agent_review.comment
FROM agent_review
         JOIN client ON agent_review.client_id = client.id
         JOIN agent ON agent_review.agent_id = agent.id
ORDER BY agent.name;

SELECT * FROM client_agent_reviews;

CREATE OR REPLACE VIEW active_contracts_by_agent AS
SELECT
    agent.name || ' ' || agent.surname AS agent_name,
    contract.id AS contract_id,
    property.name AS property_name,
    contract.start_date,
    contract.end_date,
    ROW_NUMBER() OVER (PARTITION BY agent.id ORDER BY contract.end_date ASC) AS contract_rank
FROM
    contract
        JOIN
    property ON contract.property_id = property.id
        JOIN
    agent ON contract.agent_id = agent.id
WHERE
    contract.status = 'active' and property.offer_type = 'rent'
ORDER BY
    agent_name, contract_rank;

SELECT * FROM active_contracts_by_agent;




DROP VIEW IF EXISTS available_properties;
DROP VIEW IF EXISTS client_agent_reviews;
DROP VIEW IF EXISTS active_contracts;