CREATE OR REPLACE FUNCTION fnc_offer_at_increasing_the_frequency_of_visits(
    p_start_date TIMESTAMP,
    p_end_date TIMESTAMP,
    p_added_transactions INTEGER,
    p_max_churn_index NUMERIC,
    p_max_discount_share NUMERIC,
    p_margin_share NUMERIC
)
    RETURNS TABLE
            (
                Customer_ID                 BIGINT,
                Start_Date                  TIMESTAMP,
                End_Date                    TIMESTAMP,
                Required_Transactions_Count NUMERIC,
                Group_Name                  VARCHAR,
                Offer_Discount_Depth        NUMERIC
            )
AS
$$
DECLARE
    p_period_determination INTEGER = EXTRACT(EPOCH FROM p_end_date - p_start_date) / 86400;
BEGIN
    RETURN QUERY (SELECT fdg.Customer_ID,
                         p_start_date         AS Start_Date,
                         p_end_date           AS End_Date,
                         ROUND(p_period_determination * Customer_Frequency) +
                         p_added_transactions AS Required_Transactions_Count,
                         fdg.Group_Name,
                         fdg.Offer_Discount_Depth
                  FROM fnc_determination_of_the_group(p_max_churn_index, p_max_discount_share,
                                                      p_margin_share) AS fdg
                           INNER JOIN mv_customers USING (customer_id)
                  WHERE Group_Rank = 1);
END;
$$ LANGUAGE PLPGSQL;

SET datestyle = 'ISO, DMY';

SELECT *
FROM fnc_offer_at_increasing_the_frequency_of_visits(p_start_date := '18.08.2022 00:00:00',
                                                     p_end_date := '18.08.2022 00:00:00', p_added_transactions := 1,
                                                     p_max_churn_index := 3, p_max_discount_share := 70,
                                                     p_margin_share := 30);

SELECT *
FROM fnc_offer_at_increasing_the_frequency_of_visits(p_start_date := '22.09.2021', p_end_date := '25.09.2021',
                                                     p_added_transactions := 3, p_max_churn_index := 5,
                                                     p_max_discount_share := 60, p_margin_share := 25);

SELECT *
FROM fnc_offer_at_increasing_the_frequency_of_visits(p_start_date := '22.09.2021', p_end_date := '25.10.2021',
                                                     p_added_transactions := 10, p_max_churn_index := 15,
                                                     p_max_discount_share := 75, p_margin_share := 25);