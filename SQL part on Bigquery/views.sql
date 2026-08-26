CREATE VIEW
`finance-ad-hoc.payment_analytics.v_daily_payment_health` AS

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

    ROUND(
        100 * SAFE_DIVIDE(
            COUNTIF(status = 'FAILED'),
            COUNT(*)
        ), 2
    ) AS failure_rate_pct,

    ROUND(SUM(amount), 2) AS transaction_value,

    ROUND(
        SUM(IF(status = 'SUCCESS', amount, 0)),
        2
    ) AS successful_transaction_value,

    ROUND(AVG(response_time_ms), 2) AS avg_response_time_ms

FROM `finance-ad-hoc.payment_analytics.transactions_clean`

GROUP BY transaction_date;

--------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------

CREATE VIEW
`finance-ad-hoc.payment_analytics.v_gateway_performance` AS

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

    ROUND(
        100 * SAFE_DIVIDE(
            COUNTIF(status = 'FAILED'),
            COUNT(*)
        ), 2
    ) AS failure_rate_pct,

    ROUND(AVG(response_time_ms), 2) AS avg_response_time_ms,

    ROUND(SUM(amount), 2) AS transaction_value,

    ROUND(
        SUM(IF(status = 'FAILED', amount, 0)),
        2
    ) AS failed_transaction_value

FROM `finance-ad-hoc.payment_analytics.transactions_clean`

GROUP BY gateway;

---------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------

CREATE VIEW
`finance-ad-hoc.payment_analytics.v_failure_analysis` AS

SELECT
    failure_reason,

    COUNT(*) AS failed_transactions,

    ROUND(SUM(amount), 2) AS failed_transaction_value,

    ROUND(AVG(amount), 2) AS avg_failed_amount,

    ROUND(
        100 * SAFE_DIVIDE(
            COUNT(*),
            SUM(COUNT(*)) OVER ()
        ), 2
    ) AS pct_of_failures

FROM `finance-ad-hoc.payment_analytics.transactions_clean`

WHERE status = 'FAILED'

GROUP BY failure_reason;

--------------------------------------------------------------------------
----------------------------------------------------------------------------------

CREATE VIEW
`finance-ad-hoc.payment_analytics.v_reconciliation` AS

SELECT
    t.transaction_id,

    t.merchant_id,

    t.gateway,

    t.transaction_timestamp,

    t.amount AS transaction_amount,

    s.settlement_date,

    s.settlement_amount,

    ROUND(
        s.settlement_amount - t.amount,
        2
    ) AS amount_difference,

    DATE_DIFF(
        s.settlement_date,
        DATE(t.transaction_timestamp),
        DAY
    ) AS settlement_cycle_days,

    CASE
        WHEN s.transaction_id IS NULL
            THEN 'MISSING_SETTLEMENT'

        WHEN ABS(t.amount - s.settlement_amount) >= 0.01
            THEN 'AMOUNT_MISMATCH'

        ELSE 'MATCHED'
    END AS reconciliation_status

FROM `finance-ad-hoc.payment_analytics.transactions_clean` t

LEFT JOIN `finance-ad-hoc.payment_analytics.settlements_clean` s
    ON t.transaction_id = s.transaction_id

WHERE t.status = 'SUCCESS';

--------------------------------------------------------------
--------------------------------------------------------------------

CREAT VIEW
`finance-ad-hoc.payment_analytics.v_settlement_performance` AS

SELECT
    DATE(t.transaction_timestamp) AS transaction_date,

    COUNT(*) AS successful_transactions,

    COUNTIF(s.transaction_id IS NOT NULL) AS settled_transactions,

    COUNTIF(s.transaction_id IS NULL) AS missing_settlements,

    ROUND(
        100 * SAFE_DIVIDE(
            COUNTIF(s.transaction_id IS NOT NULL),
            COUNT(*)
        ), 2
    ) AS settlement_completion_rate_pct,

    ROUND(
        AVG(
            DATE_DIFF(
                s.settlement_date,
                DATE(t.transaction_timestamp),
                DAY
            )
        ), 2
    ) AS avg_settlement_cycle_days,

    ROUND(
        SUM(t.amount),
        2
    ) AS successful_transaction_value,

    ROUND(
        SUM(IF(s.transaction_id IS NOT NULL, s.settlement_amount, 0)),
        2
    ) AS settled_value

FROM `finance-ad-hoc.payment_analytics.transactions_clean` t

LEFT JOIN `finance-ad-hoc.payment_analytics.settlements_clean` s
    ON t.transaction_id = s.transaction_id

WHERE t.status = 'SUCCESS'

GROUP BY transaction_date;
