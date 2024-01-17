CREATE INDEX IF NOT EXISTS idx_personal_data_customer_id ON "Personal_Data" (Customer_ID);
CREATE INDEX IF NOT EXISTS idx_cards_customer_id ON "Cards" (Customer_ID);
CREATE INDEX IF NOT EXISTS idx_transactions_customer_card_id ON "Transactions" (Customer_Card_ID);
CREATE INDEX IF NOT EXISTS idx_transactions_transaction_id ON "Transactions" (Transaction_ID);
CREATE INDEX IF NOT EXISTS idx_transactions_transaction_summ ON "Transactions" (Transaction_Summ);
CREATE INDEX IF NOT EXISTS idx_transactions_transactions_datetime ON "Transactions" (Transaction_DateTime);
CREATE INDEX IF NOT EXISTS idx_transactions_transaction_store_id ON "Transactions" (Transaction_Store_ID);

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_customers AS
WITH average_check AS (SELECT Customer_ID,
                              AVG(Transaction_Summ) AS Customer_Average_Check,
                              CASE
                                  WHEN PERCENT_RANK() OVER (ORDER BY AVG(Transaction_Summ) DESC) <= 0.1
                                      THEN 'High'
                                  WHEN PERCENT_RANK() OVER (ORDER BY AVG(Transaction_Summ) DESC) <= 0.35
                                      THEN 'Medium'
                                  ELSE 'Low'
                                  END               AS Customer_Average_Check_Segment
                       FROM "Cards"
                                INNER JOIN "Transactions" USING (Customer_Card_ID)
                       GROUP BY Customer_ID),
     frequency_and_churn AS (WITH ranked_visits AS (SELECT Customer_ID,
                                                           (EXTRACT(EPOCH FROM MAX(Transaction_DateTime) -
                                                                               MIN(Transaction_DateTime)) / 86400 /
                                                            COUNT(Transaction_ID))::NUMERIC                                 AS Customer_Frequency,
                                                           PERCENT_RANK()
                                                           OVER (ORDER BY (SELECT (SELECT EXTRACT(EPOCH FROM
                                                                                                  MAX(Transaction_DateTime) -
                                                                                                  MIN(Transaction_DateTime)) /
                                                                                          86400 /
                                                                                          COUNT(Transaction_ID)::NUMERIC))) AS Rank
                                                    FROM "Cards"
                                                             INNER JOIN "Transactions" USING (Customer_Card_ID)
                                                    GROUP BY "Cards".Customer_ID)
                             SELECT Customer_ID,
                                    Customer_Frequency,
                                    CASE
                                        WHEN rank <= 0.1 THEN 'Often'
                                        WHEN rank <= 0.35 THEN 'Occasionally'
                                        ELSE 'Rarely'
                                        END                    AS Customer_Frequency_Segment,
                                    EXTRACT(EPOCH FROM Analysis_Formation - MAX(Transaction_DateTime)) /
                                    86400                      AS Customer_Inactive_Period,
                                    EXTRACT(EPOCH FROM Analysis_Formation - MAX(Transaction_DateTime)) /
                                    86400 / Customer_Frequency AS Customer_Churn_Rate,
                                    CASE
                                        WHEN (EXTRACT(EPOCH FROM Analysis_Formation - MAX(Transaction_DateTime)) /
                                              86400 / Customer_Frequency) <= 2
                                            THEN 'Low'
                                        WHEN (EXTRACT(EPOCH FROM Analysis_Formation - MAX(Transaction_DateTime)) /
                                              86400 / Customer_Frequency) <= 5
                                            THEN 'Medium'
                                        ELSE 'High'
                                        END                    AS Customer_Churn_Segment
                             FROM "Date_Of_Analysis_Formation",
                                  "Transactions"
                                      INNER JOIN "Cards" USING (Customer_Card_ID)
                                      INNER JOIN ranked_visits USING (Customer_ID)
                             GROUP BY Customer_ID, Analysis_Formation, Customer_Frequency, Rank),
     three_most_recent AS (SELECT Customer_ID,
                                  Transaction_ID,
                                  Transaction_Store_ID,
                                  CASE
                                      WHEN LAG(Transaction_Store_ID)
                                           OVER ( PARTITION BY Customer_ID, Transaction_Store_ID) =
                                           Transaction_Store_ID
                                          THEN 1 END AS same_store
                           FROM "Transactions"
                                    INNER JOIN "Cards" USING (Customer_Card_ID)
                           WHERE Transaction_ID IN (SELECT Transaction_ID
                                                    FROM "Transactions"
                                                             INNER JOIN public."Cards" C
                                                                        on "Transactions".Customer_Card_ID = C.Customer_Card_ID
                                                    WHERE c.Customer_ID = "Cards".Customer_ID
                                                    ORDER BY Transaction_DateTime DESC
                                                    LIMIT 3)),
     same_store AS (SELECT Customer_ID,
                           Transaction_Store_ID
                    FROM three_most_recent
                    GROUP BY Customer_ID, Transaction_Store_ID
                    HAVING SUM(same_store) = 2),
     share_of_transactions AS (SELECT Customer_ID,
                                      Transaction_Store_ID,
                                      COUNT(*)::NUMERIC /
                                      (SELECT COUNT(*)
                                       FROM "Transactions" AS t
                                                INNER JOIN "Cards" AS c USING (Customer_Card_ID)
                                       WHERE c.Customer_ID = "Cards".Customer_ID)::NUMERIC AS Share
                               FROM "Transactions"
                                        INNER JOIN "Cards" USING (Customer_Card_ID)
                               GROUP BY Customer_ID, Transaction_Store_ID),
     max_share AS (SELECT Customer_ID,
                          Transaction_Store_ID
                   FROM share_of_transactions
                   WHERE Share = (SELECT MAX(Share)
                                  FROM share_of_transactions sot
                                  WHERE sot.Customer_ID = share_of_transactions.Customer_ID)),
     main_store AS (SELECT Customer_ID,
                           COALESCE(same_store.Transaction_Store_ID,
                                    (SELECT ms.Transaction_Store_ID
                                     FROM max_share ms
                                              INNER JOIN "Cards" USING (Customer_ID)
                                              NATURAL JOIN "Transactions"
                                     WHERE ms.Customer_ID = max_share.Customer_ID
                                     ORDER BY Transaction_DateTime DESC
                                     LIMIT 1)) AS Customer_Primary_Store
                    FROM max_share
                             FULL JOIN same_store USING (Customer_ID)
                    GROUP BY Customer_ID, same_store.Transaction_Store_ID, max_share.Customer_ID
                    ORDER BY Customer_ID, same_store.Transaction_Store_ID, max_share.Customer_ID)
SELECT "Personal_Data".Customer_ID,
       Customer_Average_Check,
       Customer_Average_Check_Segment,
       Customer_Frequency,
       Customer_Frequency_Segment,
       Customer_Inactive_Period,
       Customer_Churn_Rate,
       Customer_Churn_Segment,
       CASE Customer_Average_Check_Segment
           WHEN 'Low' THEN 0
           WHEN 'Medium' THEN 9
           WHEN 'High' THEN 18 END +
       CASE Customer_Frequency_Segment
           WHEN 'Rarely' THEN 0
           WHEN 'Occasionally' THEN 3
           WHEN 'Often' THEN 6 END +
       CASE Customer_Churn_Segment
           WHEN 'Low' THEN 1
           WHEN 'Medium' THEN 2
           WHEN 'High' THEN 3
           END AS Customer_Segment,
       Customer_Primary_Store
FROM "Personal_Data"
         LEFT JOIN average_check USING (Customer_ID)
         LEFT JOIN frequency_and_churn USING (Customer_ID)
         LEFT JOIN main_store USING (Customer_ID)
ORDER BY Customer_ID;

SELECT *
FROM mv_customers;

SELECT Customer_Average_Check_Segment,
       Customer_Frequency_Segment,
       Customer_Churn_Segment
FROM mv_customers;

SELECT Customer_ID,
       Customer_Average_Check,
       Customer_Average_Check_Segment
FROM mv_customers;