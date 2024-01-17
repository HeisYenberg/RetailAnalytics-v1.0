CREATE ROLE Administrator;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO Administrator;
SET ROLE Administrator;

SELECT *
FROM "Personal_Data";

INSERT INTO "Date_Of_Analysis_Formation"
VALUES (NOW());

DELETE
FROM "Date_Of_Analysis_Formation"
WHERE Analysis_Formation = (SELECT MAX(Analysis_Formation)
                            FROM "Date_Of_Analysis_Formation");

RESET ROLE;

CREATE ROLE Visitor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO Visitor;
SET ROLE Visitor;

SELECT *
FROM "Personal_Data";

INSERT INTO "Date_Of_Analysis_Formation"
VALUES (NOW());

DELETE
FROM "Date_Of_Analysis_Formation"
WHERE Analysis_Formation = (SELECT MAX(Analysis_Formation)
                            FROM "Date_Of_Analysis_Formation");