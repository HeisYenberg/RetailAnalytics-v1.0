CREATE INDEX IF NOT EXISTS idx_mv_groups_customer_id ON mv_groups (Customer_ID);
CREATE INDEX IF NOT EXISTS idx_mv_groups_group_affinity_index ON mv_groups (Group_Affinity_Index);
CREATE INDEX IF NOT EXISTS idx_mv_groups_group_churn_rate ON mv_groups (Group_Churn_Rate);
CREATE INDEX IF NOT EXISTS idx_mv_groups_group_stability_index ON mv_groups (Group_Stability_Index);
CREATE INDEX IF NOT EXISTS idx_stores_sku_id ON "Stores" (SKU_ID);
CREATE INDEX IF NOT EXISTS idx_checks_sku_id ON "Checks" (SKU_ID);
CREATE INDEX IF NOT EXISTS idx_sku_sku_name ON "SKU" (SKU_Name);

CREATE OR REPLACE FUNCTION fnc_offer_at_cross_selling(
    p_num_groups INTEGER,
    p_max_churn_index DECIMAL,
    p_max_stability_index DECIMAL,
    p_max_sku_share DECIMAL,
    p_margin_share DECIMAL
)
    RETURNS TABLE
            (
                Customer_ID          BIGINT,
                SKU_Name             VARCHAR,
                Offer_Discount_Depth NUMERIC
            )
AS
$$
WITH ranked_groups AS (SELECT Customer_ID,
                             Group_ID,
                             Group_Minimum_Discount,
                             ROW_NUMBER()
                             OVER (PARTITION BY Customer_ID ORDER BY Group_Affinity_Index DESC) AS group_rank
                      FROM mv_groups
                      WHERE Group_Churn_Rate <= p_max_churn_index
                        AND Group_Stability_Index < p_max_stability_index),
     calculate_margin AS (SELECT Customer_ID,
                                 SKU_Name,
                                 SUM(SKU_Retail_Price - SKU_Purchase_Price)                                               AS sku_margin,
                                 ROW_NUMBER()
                                 OVER (PARTITION BY Customer_ID ORDER BY SUM(SKU_Retail_Price - SKU_Purchase_Price) DESC) AS margin_rank
                          FROM ranked_groups
                                   INNER JOIN "SKU" USING (Group_ID)
                                   INNER JOIN "Stores" USING (SKU_ID)
                          WHERE group_rank <= p_num_groups
                          GROUP BY Customer_ID, SKU_Name),
     sku_transactions AS (SELECT Customer_ID,
                                 SKU_Name,
                                 COUNT(DISTINCT Transaction_ID) AS sku_count
                          FROM "Checks"
                                   INNER JOIN "SKU" USING (SKU_ID)
                                   INNER JOIN calculate_margin USING (SKU_Name)
                          GROUP BY Customer_ID, SKU_Name),
     group_transactions AS (SELECT Customer_ID,
                                   Group_ID,
                                   COUNT(DISTINCT Transaction_ID) AS group_count
                            FROM "Checks"
                                     INNER JOIN "SKU" USING (SKU_ID)
                                     INNER JOIN ranked_groups USING (Group_ID)
                            GROUP BY Customer_ID, Group_ID)
SELECT DISTINCT Customer_ID,
                SKU_Name,
                CEIL(Group_Minimum_Discount / 0.05) * 5.0 AS Offer_Discount_Depth
FROM calculate_margin
         INNER JOIN ranked_groups USING (Customer_ID)
         INNER JOIN sku_transactions USING (SKU_Name, Customer_ID)
         INNER JOIN group_transactions USING (Group_ID, Customer_ID)
         INNER JOIN "SKU" USING (SKU_Name, Group_ID)
         INNER JOIN "Stores" USING (SKU_ID)
WHERE group_rank <= p_num_groups
  AND margin_rank = 1
  AND sku_count / group_count < p_max_sku_share / 100
  AND p_margin_share * (SKU_Retail_Price - "Stores".SKU_Purchase_Price) / SKU_Retail_Price >=
      CEIL(Group_Minimum_Discount / 0.05) * 5.0;
$$ LANGUAGE SQL;

SELECT *
FROM fnc_offer_at_cross_selling(5, 3, 0.5, 100, 30);

SELECT *
FROM fnc_offer_at_cross_selling(3, 2, 5, 80, 50);

SELECT *
FROM fnc_offer_at_cross_selling(1, 7, 0.7, 70, 25);