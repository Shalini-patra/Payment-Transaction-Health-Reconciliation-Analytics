---What is the overall payment success rate?

select countif(status = 'SUCCESS') AS success_count, 
       countif(status = 'FAILURE') AS failure_count, 
       count(*) AS total_count ,
       round(100 * safe_divide(countif(status = 'SUCCESS'), count(*)),2) AS success_rate_pct ,
       round(100 * safe_divide(countif(status = 'FAILURE'), count(*)),2) AS failure_rate_pct ,
       sum(if(status = 'SUCCESS' , amount, 0)) AS successful_trans_val ,
       sum(amount) as tot_trans_val
from `finance-ad-hoc.payment_analytics.transactions_clean`;

--- How is payment success changing over time?---------

SELECT
    DATE(transaction_timestamp) AS transaction_date,

    COUNT(*) AS total_transactions,

    COUNTIF(status = 'SUCCESS') AS successful_transactions,

    COUNTIF(status = 'FAILED') AS failed_transactions,

    ROUND(
        100 * SAFE_DIVIDE(
            COUNTIF(status = 'SUCCESS'),
            COUNT(*)
        ), 2
    ) AS success_rate_pct,

    ROUND(SUM(amount), 2) AS transaction_value

FROM `finance-ad-hoc.payment_analytics.transactions_clean`

GROUP BY transaction_date
ORDER BY transaction_date;

---- 3. Are there sudden drops in payment success?

WITH daily AS (
    SELECT
        DATE(transaction_timestamp) AS transaction_date,

        COUNT(*) AS total_transactions,

        COUNTIF(status = 'SUCCESS') AS successful_transactions,

        100 * SAFE_DIVIDE(
            COUNTIF(status = 'SUCCESS'),
            COUNT(*)
        ) AS success_rate_pct

    FROM `finance-ad-hoc.payment_analytics.transactions_clean`

    GROUP BY transaction_date
)

SELECT *
FROM daily
WHERE success_rate_pct < 95
ORDER BY transaction_date;


---- 4. Why are transactions failing?---

SELECT
    failure_reason,
    COUNT(*) AS failed_transactions,
    ROUND(SUM(amount), 2) AS failed_transaction_value,
    ROUND(100 * SAFE_DIVIDE(COUNT(*),SUM(COUNT(*)) OVER ()), 2 ) AS pct_of_failures
FROM `finance-ad-hoc.payment_analytics.transactions_clean`
WHERE status = 'FAILED'
GROUP BY failure_reason
ORDER BY failed_transactions DESC;

--------5. Which failure reasons cause the biggest monetary impact?

SELECT
    failure_reason,
    COUNT(*) AS failed_transactions,
    ROUND(SUM(amount), 2) AS failed_value,
    ROUND(AVG(amount), 2) AS avg_failed_transaction_value
FROM `finance-ad-hoc.payment_analytics.transactions_clean`
WHERE status = 'FAILED'
GROUP BY failure_reason
ORDER BY failed_value DESC;


----6. Which payment gateway has the highest/lowest success rate?

SELECT
    gateway,
    COUNT(*) AS total_transactions,
    COUNTIF(status = 'SUCCESS') AS successful_transactions,
    COUNTIF(status = 'FAILED') AS failed_transactions,
    ROUND(
        100 * SAFE_DIVIDE(
            COUNTIF(status = 'SUCCESS'),
            COUNT(*)
        ), 2
    ) AS success_rate_pct,
    ROUND(AVG(response_time_ms), 2) AS avg_response_time_ms,
    ROUND(SUM(amount), 2) AS transaction_value
FROM `finance-ad-hoc.payment_analytics.transactions_clean`
GROUP BY gateway
ORDER BY success_rate_pct DESC;

---7. Which gateway is slowest?

SELECT
    gateway,
    COUNT(*) AS transactions,
    ROUND(AVG(response_time_ms), 2) AS avg_response_time_ms,
    ROUND(
        APPROX_QUANTILES(response_time_ms, 100)[OFFSET(95)],
        2
    ) AS p95_response_time_ms
FROM `finance-ad-hoc.payment_analytics.transactions_clean`
GROUP BY gateway
ORDER BY avg_response_time_ms DESC;

---8. Does slower gateway response correlate with payment failures?

SELECT
    gateway,
    CASE
        WHEN response_time_ms < 500 THEN '<500ms'
        WHEN response_time_ms < 1000 THEN '500-1000ms'
        WHEN response_time_ms < 2000 THEN '1000-2000ms'
        ELSE '2000ms+'
    END AS response_bucket,
    COUNT(*) AS transactions,
    ROUND(
        100 * SAFE_DIVIDE(
            COUNTIF(status = 'SUCCESS'),
            COUNT(*)
        ), 2
    ) AS success_rate_pct
FROM `finance-ad-hoc.payment_analytics.transactions_clean`
GROUP BY gateway, response_bucket
ORDER BY gateway, response_bucket;

------ revised 4th ques
SELECT
    COUNT(*) AS successful_transactions,
    COUNTIF(s.transaction_id IS NOT NULL) AS settled_transactions,
    COUNTIF(s.transaction_id IS NULL) AS missing_settlements,
    ROUND(
        100 * SAFE_DIVIDE(
            COUNTIF(s.transaction_id IS NOT NULL),
            COUNT(*)
        ), 2
    ) AS settlement_completion_rate_pct
FROM `finance-ad-hoc.payment_analytics.transactions_clean` t
LEFT JOIN `finance-ad-hoc.payment_analytics.settlements_clean` s
    ON t.transaction_id = s.transaction_id
WHERE t.status = 'SUCCESS';

-----

SELECT
    COUNT(*) AS matched_records,

    COUNTIF(
        ABS(t.amount - s.settlement_amount) < 0.01
    ) AS matching_amounts,

    COUNTIF(
        ABS(t.amount - s.settlement_amount) >= 0.01
    ) AS mismatched_amounts,

    ROUND(
        100 * SAFE_DIVIDE(
            COUNTIF(
                ABS(t.amount - s.settlement_amount) >= 0.01
            ),
            COUNT(*)
        ), 2
    ) AS mismatch_rate_pct

FROM `finance-ad-hoc.payment_analytics.transactions_clean` t

JOIN `finance-ad-hoc.payment_analytics.settlements_clean` s
    ON t.transaction_id = s.transaction_id

WHERE t.status = 'SUCCESS';

-----------------

SELECT
    ROUND(
        AVG(
            DATE_DIFF(
                s.settlement_date,
                DATE(t.transaction_timestamp),
                DAY
            )
        ), 2
    ) AS avg_settlement_cycle_days,

    COUNT(*) AS settled_transactions

FROM `finance-ad-hoc.payment_analytics.transactions_clean` t

JOIN `finance-ad-hoc.payment_analytics.settlements_clean` s
    ON t.transaction_id = s.transaction_id

WHERE t.status = 'SUCCESS';

----9. Which payment method performs best?

SELECT
    payment_method,
    COUNT(*) AS transactions,
    COUNTIF(status = 'SUCCESS') AS successful_transactions,
    ROUND(
        100 * SAFE_DIVIDE(
            COUNTIF(status = 'SUCCESS'),
            COUNT(*)
        ), 2
    ) AS success_rate_pct,
    ROUND(AVG(amount), 2) AS avg_transaction_amount
FROM `finance-ad-hoc.payment_analytics.transactions_clean`
GROUP BY payment_method
ORDER BY success_rate_pct DESC;

---Q10. Which merchants have the highest transaction volume?

SELECT
    merchant_id,
    COUNT(*) AS total_transactions,
    ROUND(SUM(amount), 2) AS transaction_value,
    ROUND(AVG(amount), 2) AS avg_transaction_value
FROM `finance-ad-hoc.payment_analytics.transactions_clean`
GROUP BY merchant_id
ORDER BY total_transactions DESC
LIMIT 20;

---11. Which merchants have unusually poor payment success rates?

SELECT
    merchant_id,
    COUNT(*) AS total_transactions,
    COUNTIF(status = 'SUCCESS') AS successful_transactions,
    ROUND(
        100 * SAFE_DIVIDE(
            COUNTIF(status = 'SUCCESS'),
            COUNT(*)
        ), 2
    ) AS success_rate_pct,
    ROUND(SUM(amount), 2) AS transaction_value
FROM `finance-ad-hoc.payment_analytics.transactions_clean`
GROUP BY merchant_id
HAVING COUNT(*) >= 100
ORDER BY success_rate_pct ASC;

---12. Which merchant categories perform poorly?

SELECT
    m.merchant_category,
    COUNT(t.transaction_id) AS transactions,
    COUNTIF(t.status = 'SUCCESS') AS successful_transactions,
    ROUND(
        100 * SAFE_DIVIDE(
            COUNTIF(t.status = 'SUCCESS'),
            COUNT(t.transaction_id)
        ), 213. What percentage of successful transactions are actually settled?
    ) AS success_rate_pct,
    ROUND(SUM(t.amount), 2) AS transaction_value
FROM `finance-ad-hoc.payment_analytics.transactions_clean` t
JOIN `finance-ad-hoc.payment_analytics.merchants_clean` m
    ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_category
ORDER BY success_rate_pct ASC;

----13. What percentage of successful transactions are actually settled?


SELECT
    COUNT(*) AS successful_transactions,
    COUNTIF(s.transaction_id IS NOT NULL) AS settled_transaction,
    COUNTIF(s.transaction_id IS NULL) AS missing_settlements,
    ROUND(
        100 * SAFE_DIVIDE(
            COUNTIF(s.transaction_id IS NOT NULL),
            COUNT(*)
        ), 2
    ) AS settlement_completion_rate_pct
FROM `finance-ad-hoc.payment_analytics.transactions_clean` t
LEFT JOIN `finance-ad-hoc.payment_analytics.settlements_clean` s
    ON t.transaction_id = s.transaction_id
WHERE t.status = 'SUCCESS';

---14. Which successful transactions are missing settlements?


SELECT
    t.transaction_id,
    t.merchant_id,
    t.gateway,
    t.transaction_timestamp,
    t.amount
FROM `finance-ad-hoc.payment_analytics.transactions_clean` t
LEFT JOIN `finance-ad-hoc.payment_analytics.settlements_clean` s
    ON t.transaction_id = s.transaction_id
WHERE t.status = 'SUCCESS'
  AND s.transaction_id IS NULL
ORDER BY t.transaction_timestamp;

---15. What is the settlement cycle?
SELECT
    DATE_DIFF(
        s.settlement_date,
        DATE(t.transaction_timestamp),
        DAY
    ) AS settlement_cycle_days,
    COUNT(*) AS transactions,
    ROUND(SUM(t.amount), 2) AS transaction_value
FROM `finance-ad-hoc.payment_analytics.transactions_clean` t
JOIN `finance-ad-hoc.payment_analytics.settlements_clean` s
    ON t.transaction_id = s.transaction_id
WHERE t.status = 'SUCCESS'
GROUP BY settlement_cycle_days
ORDER BY settlement_cycle_days;

---16. Which merchants experience longer settlement cycles?

SELECT
    t.merchant_id,
    COUNT(*) AS settled_transactions,
    ROUND(
        AVG(
            DATE_DIFF(
                s.settlement_date,
                DATE(t.transaction_timestamp),
                DAY
            )
        ), 2
    ) AS avg_settlement_cycle_days,
    MAX(
        DATE_DIFF(
            s.settlement_date,
            DATE(t.transaction_timestamp),
            DAY
        )
    ) AS max_settlement_cycle_days
FROM `finance-ad-hoc.payment_analytics.transactions_clean` 
JOIN `finance-ad-hoc.payment_analytics.settlements_clean` s
    ON t.transaction_id = s.transaction_id
WHERE t.status = 'SUCCESS'
GROUP BY t.merchant_i
HAVING COUNT(*) >= 50
ORDER BY avg_settlement_cycle_days DESC;

---17.Are transaction amounts and settlement amounts matching?

SELECT
    COUNT(*) AS matched_records,
    COUNTIF(
        ABS(t.amount - s.settlement_amount) < 0.01
    ) AS matching_amounts,
    COUNTIF(
        ABS(t.amount - s.settlement_amount) >= 0.01
    ) AS mismatched_amounts,
    ROUND(
        100 * SAFE_DIVIDE(
            COUNTIF(
                ABS(t.amount - s.settlement_amount) >= 0.01
            ),
            COUNT(*)
        ), 2
    ) AS mismatch_rate_pc
FROM `finance-ad-hoc.payment_analytics.transactions_clean` t
JOIN `finance-ad-hoc.payment_analytics.settlements_clean` s
    ON t.transaction_id = s.transaction_id
WHERE t.status = 'SUCCESS';

----18. Show the actual mismatched transactions

SELECT
    t.transaction_id,
    t.merchant_id,
    t.gateway,
    t.amount AS transaction_amount,
    s.settlement_amount,
    ROUND(
        s.settlement_amount - t.amount,
        2
    ) AS amount_difference,
    t.transaction_timestamp,
    s.settlement_date
FROM `finance-ad-hoc.payment_analytics.transactions_clean` t
JOIN `finance-ad-hoc.payment_analytics.settlements_clean` s
    ON t.transaction_id = s.transaction_id
WHERE t.status = 'SUCCESS'
  AND ABS(t.amount - s.settlement_amount) >= 0.01

ORDER BY ABS(t.amount - s.settlement_amount) DESC;


----19. What is the total reconciliation gap?


SELECT
    ROUND(SUM(t.amount), 2) AS transaction_value,
    ROUND(SUM(s.settlement_amount), 2) AS settlement_value,
    ROUND(
        SUM(s.settlement_amount) - SUM(t.amount),
        2
    ) AS reconciliation_gap
FROM `finance-ad-hoc.payment_analytics.transactions_clean` t
JOIN `finance-ad-hoc.payment_analytics.settlements_clean` s
    ON t.transaction_id = s.transaction_id
WHERE t.status = 'SUCCESS';

