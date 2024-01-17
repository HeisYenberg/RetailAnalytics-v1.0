CREATE OR REPLACE FUNCTION fnc_check_measure_by_period(p_start_date DATE,
                                                       p_end_date DATE, p_average_check_increase NUMERIC)
    RETURNS TABLE
            (
                Customer_ID            BIGINT,
                Required_Check_Measure NUMERIC
            )
AS
$$
SELECT Customer_ID,
       ROUND(AVG(Transaction_Summ) * p_average_check_increase, 2) AS Required_Check_Measure
FROM "Cards"
         INNER JOIN "Transactions" USING (Customer_Card_ID)
WHERE Transaction_DateTime BETWEEN p_start_date AND p_end_date
GROUP BY Customer_ID;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION fnc_check_measure_by_number_of_transactions(p_transaction_count INTEGER, p_average_check_increase NUMERIC)
    RETURNS TABLE
            (
                Customer_ID            BIGINT,
                Required_Check_Measure NUMERIC
            )
AS
$$
SELECT Customer_ID,
       ROUND(AVG(Transaction_Summ) * p_average_check_increase, 2) AS Required_Check_Measure
FROM (SELECT *,
             ROW_NUMBER()
             OVER (PARTITION BY Customer_ID ORDER BY Transaction_DateTime DESC) AS transaction_rank
      FROM "Cards"
               INNER JOIN "Transactions" USING (Customer_Card_ID)
               INNER JOIN "Checks" USING (Transaction_ID)
               INNER JOIN "SKU" USING (SKU_ID)) AS ranked_trasactions
WHERE transaction_rank <= p_transaction_count
GROUP BY Customer_ID;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION fnc_determination_of_the_group(p_max_churn_index NUMERIC, p_max_discount_share NUMERIC,
                                                          p_margin_share NUMERIC)
    RETURNS TABLE
            (
                Customer_ID          BIGINT,
                Group_Name           VARCHAR,
                Offer_Discount_Depth NUMERIC,
                Group_Rank           BIGINT
            )
AS
$$
WITH calculate_margin AS (SELECT AVG(group_summ_paid - group_cost) avg_margin,
                                 Customer_ID,
                                 group_id
                          FROM mv_purchase_history
                          GROUP BY Customer_ID, group_id)
SELECT Customer_ID,
       Group_Name,
       CEIL(Group_Minimum_Discount / 0.05) * 5.0,
       ROW_NUMBER() OVER (PARTITION BY Customer_ID ORDER BY group_affinity_index DESC) AS Group_Rank
FROM mv_groups AS mg
         INNER JOIN "Groups_SKU" USING (group_id)
         NATURAL JOIN calculate_margin
WHERE Group_Churn_Rate <= p_max_churn_index
  AND Group_Discount_Share < p_max_discount_share::NUMERIC / 100
  AND CEIL(Group_Minimum_Discount / 0.05) * 5.0 < (p_margin_share::NUMERIC / 100 * avg_margin);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION fnc_offer_at_growth_of_the_average_check(
    p_calculation_method INTEGER,
    p_start_date DATE,
    p_end_date DATE,
    p_transaction_count INTEGER,
    p_average_check_increase NUMERIC,
    p_max_churn_index NUMERIC,
    p_max_discount_share NUMERIC,
    p_margin_share NUMERIC
)
    RETURNS TABLE
            (
                Customer_ID            BIGINT,
                Required_Check_Measure NUMERIC,
                Group_Name             VARCHAR,
                Offer_Discount_Depth   NUMERIC
            )
AS
$$
BEGIN
    IF p_calculation_method = 1 THEN
        IF NOT EXISTS(SELECT 1 FROM mv_purchase_history WHERE Transaction_DateTime >= p_start_date) THEN
            p_start_date = (SELECT MIN(Transaction_DateTime) FROM mv_purchase_history);
        END IF;
        IF p_start_date >= p_end_date THEN
            p_end_date = (SELECT MAX(Transaction_DateTime) FROM mv_purchase_history);
        END IF;
        RETURN QUERY (SELECT fcm.Customer_ID,
                             fcm.Required_Check_Measure,
                             fdg.Group_Name,
                             fdg.Offer_Discount_Depth
                      FROM fnc_check_measure_by_period(p_start_date, p_end_date, p_average_check_increase) AS fcm
                               INNER JOIN fnc_determination_of_the_group(p_max_churn_index, p_max_discount_share,
                                                                         p_margin_share) fdg USING (Customer_ID)
                      WHERE Group_Rank = 1);
    ELSIF p_calculation_method = 2 THEN
        RETURN QUERY (SELECT fcm.Customer_ID,
                             fcm.Required_Check_Measure,
                             fdg.Group_Name,
                             fdg.Offer_Discount_Depth
                      FROM fnc_check_measure_by_number_of_transactions(p_transaction_count,
                                                                       p_average_check_increase) AS fcm
                               INNER JOIN fnc_determination_of_the_group(p_max_churn_index, p_max_discount_share,
                                                                         p_margin_share) fdg USING (Customer_ID)
                      WHERE Group_Rank = 1);
    END IF;
END;
$$ LANGUAGE PLPGSQL;

SELECT *
FROM fnc_offer_at_growth_of_the_average_check(p_calculation_method := 2, p_start_date := NULL, p_end_date := NULL,
                                              p_transaction_count := 100, p_average_check_increase := 1.15,
                                              p_max_churn_index := 3, p_max_discount_share := 70, p_margin_share := 30);

SELECT *
FROM fnc_offer_at_growth_of_the_average_check(p_calculation_method := 2, p_start_date := NULL, p_end_date := NULL,
                                              p_transaction_count := 10, p_average_check_increase := 1.5,
                                              p_max_churn_index := 2.5, p_max_discount_share := 90,
                                              p_margin_share := 15);

SET datestyle = 'ISO, DMY';

SELECT *
FROM fnc_offer_at_growth_of_the_average_check(p_calculation_method := 1, p_start_date := '22.09.2019',
                                              p_end_date := '22.09.2021', p_transaction_count := NULL,
                                              p_average_check_increase := 1.5, p_max_churn_index := 2.5,
                                              p_max_discount_share := 90, p_margin_share := 15);

SELECT *
FROM fnc_offer_at_growth_of_the_average_check(p_calculation_method := 1, p_start_date := '22.09.2019',
                                              p_end_date := '22.09.2021', p_transaction_count := NULL,
                                              p_average_check_increase := 3, p_max_churn_index := 5,
                                              p_max_discount_share := 60, p_margin_share := 25);

SELECT *
FROM fnc_offer_at_growth_of_the_average_check(p_calculation_method := 1, p_start_date := '22.09.2019',
                                              p_end_date := '22.09.2019', p_transaction_count := NULL,
                                              p_average_check_increase := 3, p_max_churn_index := 5,
                                              p_max_discount_share := 60, p_margin_share := 25);