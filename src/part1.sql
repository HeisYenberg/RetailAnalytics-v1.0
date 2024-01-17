CREATE DATABASE s21_retail;

CREATE TABLE IF NOT EXISTS "Personal_Data"
(
    Customer_ID            BIGSERIAL PRIMARY KEY NOT NULL,
    Customer_Name          VARCHAR CHECK (Customer_Name ~ '^[A-Za-zА-Яа-я][A-Za-zА-Яа-я -]+$'),
    Customer_Surname       VARCHAR CHECK (Customer_Surname ~ '^[A-Za-zА-Яа-я][A-Za-zА-Яа-я -]+$'),
    Customer_Primary_Email VARCHAR CHECK (Customer_Primary_Email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT ch_unique_customer_primary_email UNIQUE (Customer_Primary_Email),
    Customer_Primary_Phone VARCHAR CHECK (Customer_Primary_Phone ~ '^\+7\d{10}$'),
    CONSTRAINT ch_unique_customer_primary_phone UNIQUE (Customer_Primary_Phone)
);

CREATE TABLE IF NOT EXISTS "Cards"
(
    Customer_Card_ID BIGSERIAL PRIMARY KEY NOT NULL,
    Customer_ID      BIGINT REFERENCES "Personal_Data" (Customer_ID)
);

CREATE TABLE IF NOT EXISTS "Groups_SKU"
(
    Group_ID   BIGSERIAL PRIMARY KEY NOT NULL,
    Group_Name VARCHAR CHECK (Group_Name ~ '^[A-Za-zА-Яа-я0-9\s[:punct:]]+$')
);

CREATE TABLE IF NOT EXISTS "SKU"
(
    SKU_ID   BIGSERIAL PRIMARY KEY NOT NULL,
    SKU_Name VARCHAR CHECK (SKU_Name ~ '^[A-Za-zА-Яа-я0-9\s[:punct:]]+$'),
    Group_ID BIGINT REFERENCES "Groups_SKU" (Group_ID)
);

CREATE TABLE IF NOT EXISTS "Stores"
(
    Transaction_Store_ID BIGINT,
    SKU_ID               BIGINT REFERENCES "SKU" (SKU_ID),
    SKU_Purchase_Price   NUMERIC,
    SKU_Retail_Price     NUMERIC
);

CREATE TABLE IF NOT EXISTS "Transactions"
(
    Transaction_ID       BIGSERIAL PRIMARY KEY NOT NULL,
    Customer_Card_ID     BIGINT REFERENCES "Cards" (Customer_Card_ID),
    Transaction_Summ     NUMERIC,
    Transaction_DateTime TIMESTAMP,
    Transaction_Store_ID BIGINT
);

CREATE TABLE IF NOT EXISTS "Checks"
(
    Transaction_ID BIGINT REFERENCES "Transactions" (Transaction_ID),
    SKU_ID         BIGINT REFERENCES "SKU" (SKU_ID),
    SKU_Amount     NUMERIC,
    SKU_Summ       NUMERIC,
    SKU_Summ_Paid  NUMERIC,
    SKU_Discount   NUMERIC
);

CREATE TABLE IF NOT EXISTS "Date_Of_Analysis_Formation"
(
    Analysis_Formation TIMESTAMP
);

CREATE OR REPLACE PROCEDURE import_from_csv(p_table_name VARCHAR, p_file_path VARCHAR, p_separator VARCHAR)
AS
$$
BEGIN
    EXECUTE FORMAT('COPY %I FROM %L WITH (FORMAT TEXT, DELIMITER %L)', p_table_name, p_file_path, p_separator);
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE import_from_tsv(p_table_name VARCHAR, p_file_path VARCHAR)
AS
$$
BEGIN
    SET datestyle = 'ISO, DMY';
    EXECUTE FORMAT('COPY %I FROM %L WITH (FORMAT TEXT, DELIMITER E''\t'')', p_table_name, p_file_path);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_to_csv(p_table_name VARCHAR, p_file_path VARCHAR)
AS
$$
BEGIN
    EXECUTE FORMAT('COPY %I TO %L WITH (FORMAT CSV)', p_table_name, p_file_path);
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE export_to_tsv(p_table_name VARCHAR, p_file_path VARCHAR)
AS
$$
BEGIN
    EXECUTE FORMAT('COPY %I TO %L WITH (FORMAT TEXT)', p_table_name, p_file_path);
END
$$ LANGUAGE plpgsql;

DO
$$
    DECLARE
        datasets_folder TEXT := '/mnt/c/Users/HeisYenberg/Developer/Projects/SQL/RetailAnalytics-v1.0/datasets';
    BEGIN
        CALL import_from_tsv('Personal_Data', CONCAT(datasets_folder, 'Personal_Data_Mini.tsv'));
        CALL import_from_tsv('Cards', CONCAT(datasets_folder, 'Cards_Mini.tsv'));
        CALL import_from_tsv('Groups_SKU', CONCAT(datasets_folder, 'Groups_SKU_Mini.tsv'));
        CALL import_from_tsv('SKU', CONCAT(datasets_folder, 'SKU_Mini.tsv'));
        CALL import_from_tsv('Stores', CONCAT(datasets_folder, 'Stores_Mini.tsv'));
        CALL import_from_tsv('Transactions', CONCAT(datasets_folder, 'Transactions_Mini.tsv'));
        CALL import_from_tsv('Checks', CONCAT(datasets_folder, 'Checks_Mini.tsv'));
        CALL import_from_tsv('Date_Of_Analysis_Formation', CONCAT(datasets_folder, 'Date_Of_Analysis_Formation.tsv'));
    END
$$; -- mini database

DO
$$
    DECLARE
        datasets_folder TEXT := '/mnt/c/Users/HeisYenberg/Developer/Projects/SQL/RetailAnalytics-v1.0/datasets';
    BEGIN
        CALL import_from_tsv('Personal_Data', CONCAT(datasets_folder, 'Personal_Data.tsv'));
        CALL import_from_tsv('Cards', CONCAT(datasets_folder, 'Cards.tsv'));
        CALL import_from_tsv('Groups_SKU', CONCAT(datasets_folder, 'Groups_SKU.tsv'));
        CALL import_from_tsv('SKU', CONCAT(datasets_folder, 'SKU.tsv'));
        CALL import_from_tsv('Stores', CONCAT(datasets_folder, 'Stores.tsv'));
        CALL import_from_tsv('Transactions', CONCAT(datasets_folder, 'Transactions.tsv'));
        CALL import_from_tsv('Checks', CONCAT(datasets_folder, 'Checks.tsv'));
        CALL import_from_tsv('Date_Of_Analysis_Formation', CONCAT(datasets_folder, 'Date_Of_Analysis_Formation.tsv'));
    END
$$; -- big database