CREATE INDEX IF NOT EXISTS idx_checks_transaction_ID ON "Checks" (Transaction_ID);
CREATE INDEX IF NOT EXISTS idx_transactions_transaction_id ON "Transactions" (Transaction_ID);
CREATE INDEX IF NOT EXISTS idx_sku_sku_id ON "SKU" (SKU_ID);
CREATE INDEX IF NOT EXISTS idx_sku_group_id ON "SKU" (Group_ID);

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_purchase_history AS
SELECT Customer_ID,
       Transaction_ID,
       Transaction_DateTime,
       Group_ID,
       SUM(SKU_Purchase_Price * SKU_Amount) AS Group_Cost,
       SUM(SKU_Summ)                        AS Group_Summ,
       SUM(SKU_Summ_Paid)                   AS Group_Summ_Paid
FROM "Personal_Data"
         LEFT JOIN "Cards" USING (Customer_ID)
         LEFT JOIN "Transactions" USING (Customer_Card_ID)
         LEFT JOIN "Checks" USING (Transaction_ID)
         LEFT JOIN "SKU" USING (SKU_ID)
         NATURAL LEFT JOIN "Stores"
GROUP BY Customer_ID, Transaction_ID, Transaction_DateTime, Group_ID
ORDER BY Customer_ID, Transaction_ID, Transaction_DateTime, Group_ID;

SELECT *
FROM mv_purchase_history;

SELECT Group_ID,
       Group_Cost,
       Group_Summ,
       Group_Summ_Paid
FROM mv_purchase_history;

SELECT Customer_ID,
       Transaction_ID,
       Transaction_DateTime
FROM mv_purchase_history;