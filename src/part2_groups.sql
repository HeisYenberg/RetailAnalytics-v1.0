CREATE INDEX IF NOT EXISTS idx_mv_purchase_history_customer_id ON mv_purchase_history (Customer_ID);
CREATE INDEX IF NOT EXISTS idx_mv_purchase_history_group_id ON mv_purchase_history (Group_ID);
CREATE INDEX IF NOT EXISTS idx_mv_purchase_history_transaction_datetime ON mv_purchase_history (Transaction_DateTime);
CREATE INDEX IF NOT EXISTS idx_mv_purchase_history_transaction_id ON mv_purchase_history (Transaction_ID);
CREATE INDEX IF NOT EXISTS idx_mv_periods_customer_id ON mv_periods (Customer_ID);
CREATE INDEX IF NOT EXISTS idx_mv_periods_group_id ON mv_periods (Group_ID);

CREATE OR REPLACE FUNCTION fnc_calculate_margin(p_period INTERVAL DEFAULT NULL, p_transactions INTEGER DEFAULT NULL)
    RETURNS TABLE
            (
                Group_Margin NUMERIC,
                Customer_ID  BIGINT,
                Group_ID     BIGINT
            )
AS
$$
SELECT SUM(Group_Summ_Paid - Group_Cost) AS Group_Margin,
       Customer_ID,
       Group_ID
FROM (SELECT *,
             ROW_NUMBER()
             OVER (PARTITION BY Customer_ID, Group_ID ORDER BY Transaction_DateTime DESC) AS transaction_number
      FROM mv_purchase_history) AS numerated_transactions
WHERE (p_period IS NULL AND p_transactions IS NULL)
   OR (p_period IS NOT NULL AND p_transactions IS NOT NULL AND
       Transaction_DateTime >= (SELECT MAX(Analysis_Formation) FROM "Date_Of_Analysis_Formation") - p_period AND
       transaction_number <= p_transactions)
   OR (p_period IS NOT NULL AND p_transactions IS NULL AND
       Transaction_DateTime >= (SELECT MAX(Analysis_Formation) FROM "Date_Of_Analysis_Formation") - p_period)
   OR (p_period IS NULL AND p_transactions IS NOT NULL AND transaction_number <= p_transactions)
GROUP BY Customer_ID, Group_ID;
$$ LANGUAGE SQL;

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_groups AS
WITH transactions_interval AS (SELECT COALESCE(EXTRACT(EPOCH FROM Transaction_DateTime -
                                                                  LAG(Transaction_DateTime)
                                                                  OVER (PARTITION BY Customer_ID, Group_ID ORDER BY Transaction_DateTime)),
                                               0)
                                          AS transaction_interval,
                                      Customer_ID,
                                      Group_ID
                               FROM mv_purchase_history),
     calculate_avg_discount AS (SELECT SUM(CASE WHEN Group_Summ_Paid = Group_Summ THEN NULL ELSE Group_Summ_Paid END) /
                                       SUM(CASE WHEN Group_Summ_Paid = Group_Summ THEN NULL ELSE Group_Summ END) AS Group_Average_Discount,
                                       Customer_ID,
                                       Group_ID
                                FROM mv_purchase_history
                                         NATURAL JOIN mv_periods
                                GROUP BY Customer_ID, Group_ID
                                ORDER BY Customer_ID, Group_ID),
     calculated_data AS (SELECT mv_periods.Customer_ID,
                                mv_periods.Group_ID,
                                MAX(Group_Purchase)::NUMERIC / COUNT(DISTINCT Transaction_ID)               AS Group_Affinity_Index,
                                MAX(EXTRACT(EPOCH FROM Analysis_Formation - Last_Group_Purchase_Date) / 86400 /
                                    Group_Frequency)                                                        AS Group_Churn_Rate,
                                COALESCE(AVG((transaction_interval / 86400 - Group_Frequency) / Group_Frequency)
                                         FILTER ( WHERE transaction_interval > 0 ),
                                         MAX(Group_Frequency))                                              AS Group_Stability_Index,
                                (SELECT COUNT(DISTINCT "Transactions".Transaction_ID)
                                 FROM "Checks"
                                          INNER JOIN "SKU" USING (SKU_ID)
                                          INNER JOIN "Transactions" USING (Transaction_ID)
                                          INNER JOIN "Cards" USING (Customer_Card_ID)
                                 WHERE SKU_Discount > 0
                                   AND "Cards".Customer_ID = mv_periods.Customer_ID
                                   AND "SKU".Group_ID = mv_periods.Group_ID)::NUMERIC /
                                MAX(Group_Purchase)::NUMERIC                                                AS Group_Discount_Share,
                                MIN(CASE WHEN Group_Min_Discount = 0 THEN NULL ELSE Group_Min_Discount END) AS Group_Minimum_Discount
                         FROM mv_periods
                                  INNER JOIN mv_purchase_history USING (Customer_ID)
                                  INNER JOIN transactions_interval
                                             ON mv_periods.Customer_ID = transactions_interval.Customer_ID
                                                 AND mv_periods.Group_ID = transactions_interval.Group_ID,
                              "Date_Of_Analysis_Formation"
                         WHERE Transaction_DateTime BETWEEN First_Group_Purchase_Date AND Last_Group_Purchase_Date
                         GROUP BY mv_periods.Customer_ID, mv_periods.Group_ID
                         ORDER BY mv_periods.Customer_ID, mv_periods.Group_ID)
SELECT Customer_ID,
       Group_ID,
       Group_Affinity_Index,
       Group_Churn_Rate,
       Group_Stability_Index,
       Group_Margin,
       Group_Discount_Share,
       Group_Minimum_Discount,
       Group_Average_Discount
FROM "Personal_Data"
         LEFT JOIN calculated_data USING (Customer_ID)
         NATURAL LEFT JOIN fnc_calculate_margin()
         NATURAL LEFT JOIN calculate_avg_discount
ORDER BY Customer_ID, Group_ID;

SELECT *
FROM mv_groups;

SELECT *
FROM mv_groups
WHERE Group_Average_Discount IS NOT NULL;

SELECT *
FROM mv_groups
WHERE Group_Margin > 0;