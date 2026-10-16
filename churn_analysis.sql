-- 1 создание таблицы
CREATE TABLE default.customer_retention_ready
(
    msno String,
    is_churn UInt8,
    city Nullable(Float64),
    bd Nullable(Float64),
    gender Nullable(String),
    registered_via Nullable(Float64),
    registration_init_time Nullable(DateTime),
    transactions_count Float64,
    payment_plan_days Nullable(Float64),
    plan_list_price Nullable(Float64),
    actual_amount_paid Nullable(Float64),
    is_auto_renew Nullable(Float64),
    is_cancel Nullable(Float64),
    transaction_date Nullable(DateTime),
    membership_expire_date Nullable(DateTime),
    plan_group Nullable(String),
    has_discount UInt8,
    payment_group Nullable(String),
    days_since_last_transaction Nullable(Float64),
    recency_group Nullable(String)
)
ENGINE = MergeTree
ORDER BY msno;


SELECT count(*)
FROM default.customer_retention_ready;


SELECT count(*) AS users,
       round(avg(is_churn) * 100, 2) AS churn_rate
FROM default.customer_retention_ready;


RENAME TABLE customer_retention_ready TO retention;


-- 1 общий churn
SELECT count(*) AS users,
       round(avg(is_churn) * 100, 2) AS churn_rate
FROM retention;


-- 2 churn по автопродлению
SELECT
    is_auto_renew,
    count(*) AS users,
    round(avg(is_churn) * 100, 2) AS churn_rate
FROM retention
GROUP BY is_auto_renew
ORDER BY is_auto_renew;


-- 3 churn по отмене подписки
SELECT
    is_cancel,
    count(*) AS users,
    round(avg(is_churn) * 100, 2) AS churn_rate
FROM retention
GROUP BY is_cancel
ORDER BY is_cancel;


-- 4 churn по кол-ву транзакций
SELECT
    CASE
        WHEN transactions_count = 0 THEN '0'
        WHEN transactions_count = 1 THEN '1'
        WHEN transactions_count BETWEEN 2 AND 3 THEN '2-3'
        WHEN transactions_count BETWEEN 4 AND 10 THEN '4-10'
        ELSE '11+'
    END AS transaction_group,
    count(*) AS users,
    round(avg(is_churn) * 100, 2) AS churn_rate
FROM retention
GROUP BY transaction_group
ORDER BY
    CASE transaction_group
        WHEN '0' THEN 1
        WHEN '1' THEN 2
        WHEN '2-3' THEN 3
        WHEN '4-10' THEN 4
        WHEN '11+' THEN 5
    END;


-- 5 churn со дня последней транзакции
SELECT
    recency_group,
    count(*) AS users,
    round(avg(is_churn) * 100, 2) AS churn_rate
FROM retention
GROUP BY recency_group
ORDER BY churn_rate;


-- 6 churn по возрасту
SELECT
    CASE
        WHEN bd < 18 THEN '<18'
        WHEN bd BETWEEN 18 AND 24 THEN '18-24'
        WHEN bd BETWEEN 25 AND 34 THEN '25-34'
        WHEN bd BETWEEN 35 AND 44 THEN '35-44'
        WHEN bd BETWEEN 45 AND 54 THEN '45-54'
        WHEN bd BETWEEN 55 AND 64 THEN '55-64'
        WHEN bd >= 65 THEN '65+'
        ELSE 'unknown'
    END AS age_group,
    count(*) AS users,
    round(avg(is_churn) * 100, 2) AS churn_rate
FROM retention
GROUP BY age_group
ORDER BY churn_rate DESC;


-- 7 churn по группе оплаченного тарифа
SELECT
    plan_group,
    count(*) AS users,
    round(avg(is_churn) * 100, 2) AS churn_rate
FROM retention
GROUP BY plan_group
ORDER BY churn_rate DESC;


-- 8 churn по тому, заплатил ли пользователь меньше стоимости тарифа или нет
SELECT
    has_discount,
    count(*) AS users,
    round(avg(is_churn) * 100, 2) AS churn_rate
FROM retention
GROUP BY has_discount
ORDER BY has_discount;


-- найти группы пользователей с самым высоким churn,
-- но учитывать только достаточно крупные группы,
-- чтобы не было ситуации, где 1 человек -> 100% churn
WITH recency_stats AS (
    SELECT
        recency_group,
        count(*) AS users,
        round(avg(is_churn) * 100, 2) AS churn_rate
    FROM retention
    GROUP BY recency_group
)
SELECT
    recency_group,
    users,
    churn_rate
FROM recency_stats
WHERE users >= 1000
ORDER BY churn_rate DESC;


WITH recency_stats AS (
    SELECT
        recency_group,
        count(*) AS users,
        round(avg(is_churn) * 100, 2) AS churn_rate
    FROM retention
    GROUP BY recency_group
)
SELECT
    recency_group,
    users,
    churn_rate,
    RANK() OVER (ORDER BY churn_rate DESC) AS churn_rank
FROM recency_stats
WHERE users >= 1000
ORDER BY churn_rank;
