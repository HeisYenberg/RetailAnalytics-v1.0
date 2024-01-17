CREATE MATERIALIZED VIEW IF NOT EXISTS mv_periods AS
WITH calculated_data AS (SELECT Customer_ID,
                                Group_ID,
                                MIN(Transaction_DateTime)      AS First_Group_Purchase_Date,
                                MAX(Transaction_DateTime)      AS Last_Group_Purchase_Date,
                                COUNT(DISTINCT Transaction_ID) AS Group_Purchase,
                                (EXTRACT(EPOCH FROM MAX(Transaction_DateTime) - MIN(Transaction_DateTime))::NUMERIC /
                                 86400 + 1) /
                                COUNT(DISTINCT Transaction_ID) AS Group_Frequency,
                                COALESCE(MIN(CASE WHEN SKU_Discount = 0 THEN NULL ELSE SKU_Discount / SKU_Summ END),
                                         0)                    AS Group_Min_Discount
                         FROM "Cards"
                                  INNER JOIN "Transactions" USING (Customer_Card_ID)
                                  INNER JOIN "Checks" USING (Transaction_ID)
                                  INNER JOIN "SKU" USING (SKU_ID)
                         GROUP BY Customer_ID, Group_ID
                         ORDER BY Customer_ID, Group_ID)
SELECT Customer_ID,
       Group_ID,
       First_Group_Purchase_Date,
       Last_Group_Purchase_Date,
       Group_Purchase,
       Group_Frequency,
       Group_Min_Discount
FROM "Personal_Data"
         LEFT JOIN calculated_data USING (Customer_ID)
ORDER BY Customer_ID, Group_ID;

SELECT *
FROM mv_periods;

SELECT Group_ID,
       First_Group_Purchase_Date,
       Last_Group_Purchase_Date
FROM mv_periods;

SELECT Group_ID,
       Group_Purchase,
       Group_Frequency,
       Group_Min_Discount
FROM mv_periods;