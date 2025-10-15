/*CREATE TABLE customer_instalments (
    loan_id character varying(100),
    partner_id uuid NOT NULL,
    discount numeric(14,2) DEFAULT 0,
    amount_to_pay numeric(14,2) NOT NULL,
    created_at timestamp NOT NULL,
    entered_at timestamp,
	deleted_at timestamp
);
DROP FROM customer_instalments



SELECT * FROM customer_instalments
WHERE discount > 0

CREATE TABLE customer_collections (
	partner_id  uuid NOT NULL,
	loan_id character varying(100)  NOT NULL,
	amount_paid numeric(14, 2) NOT NULL,
	self_payment numeric(14, 2) DEFAULT 0,
	auto_debit numeric(14, 2) DEFAULT 0,
	balance_before numeric(14, 2),
	balance_after numeric(14, 2),
	paid_at date,
	created_at timestamp
);

SELECT * FROM customer_collections
partner_id, loan_id, amount_paid, self_payment, auto_debit, balance_before, balance_after, paid_at, created_at

SELECT * FROM collections


--simple balance per loan
-- balance = amount_to_pay - discount - sum(amount_paid)


SELECT 
	ci.loan_id,
	ci.amount_to_pay,
	ci.discount,
	COALESCE(cc.total_paid, 0)
FROM customer_instalments ci
LEFT JOIN (
	SELECT 
		SUM(amount_paid) as total_paid
	FROM 
		collections cc
	ON ci.loan_id = cc.loan_id
WHERE ci.partner_id = cc.partner_id
)
ORDER BY loan_id 
	

SELECT
    ci.partner_id,
    ci.loan_id,
    ci.amount_to_pay,
    ci.discount,
    ci.amount_to_pay - ci.discount - COALESCE(SUM(cc.amount_paid), 0) AS balance
FROM customer_instalments ci
LEFT JOIN collections cc
    ON ci.partner_id = cc.partner_id
	
   AND ci.loan_id = cc.loan_id
GROUP BY ci.partner_id, ci.loan_id,whats ci.amount_to_pay, ci.discount
ORDER BY ci.loan_id;


SELECT * FROM customer_collections
WHERE loan_id = '928573779228dc4d8ed1ce6f66e80c62'
ORDER BY paid_at

SELECT 
	loan_id,
	COUNT(*) as county
FROM customer_collections
GROUP BY loan_id
ORDER BY county DESC

SELECT * FROM customer_instalments
WHERE loan_id = '928573779228dc4d8ed1ce6f66e80c62'
 SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('customer_instalments', 'customer_collections');

ALTER TABLE collections RENAME TO customer_collections


SELECT
	column_name,
	data_type
FROM information_schema.columns
WHERE table_name IN ('customer_instalments', 'customer_collections')


#lets goo

SELECT
	COUNT(DISTINCT loan_id) as total_loans
FROM customer_instalments

DROP TABLE staging_customer_collections


WITH events AS (
  -- Loan creation event
  SELECT
    ci.loan_id,
    ci.created_at,
    'creation' AS event_type,
    (ci.amount_to_pay - ci.discount) AS amount_change
  FROM customer_instalments ci

  UNION ALL

  -- Payment event
  SELECT
 	cc.loan_id,
    cc.created_at,
    'payment' AS event_type,
    -cc.amount_paid AS amount_change
  FROM customer_collections cc
)
SELECT
  loan_id,
  event_type,
  created_at,
  amount_change
FROM events
ORDER BY loan_id, created_at;


WITH the_events AS(
	SELECT
		ci.loan_id,
		ci.created_at as event_time,
		'creation' as event_type,
		(amount_to_pay - discount) as amount_change
	FROM 
		customer_instalments ci
	

	UNION ALL

	SELECT 
		cc.loan_id,
		COALESCE (cc.paid_at::timestamp, cc.created_at) as event_time,
		'payment' as event_type,
		-cc.amount_paid as amount_change
	FROM 
		customer_collections cc
	WHERE balance_after > 0.0
	

	UNION ALL

	SELECT
		cc.loan_id, 
		COALESCE (cc.paid_at::timestamp, cc.created_at) as event_time,
		'completed' as event_type,
		-cc.amount_paid as amount_change
	FROM customer_collections cc
	WHERE balance_after = 0.00
)
SELECT
	e.loan_id, 
	e.event_time,
	e.event_type,
	cc.balance_before,
	e.amount_change,
	cc.balance_after
FROM the_events e
LEFT JOIN customer_collections cc
ON 
	e.loan_id = cc.loan_id
AND
	COALESCE (cc.paid_at::timestamp, cc.created_at) = e.event_time
--GROUP BY e.loan_id, event_time, event_type, paid_at, balance_after, balance_before, amount_change
ORDER BY loan_id, balance_after DESC



/*SELECT * FROM customer_collections
WHERE loan_id = '003c1e184f4bcae943787a9e4116c3eb'*/


SELECT * FROM customer_instalments
ORDER BY loan_id


SELECT * FROM customer_collections

SELECT 
	paid_at,
	amount_paid,
	discount,
	SUM(amount_paid) OVER(PARTITION BY loan_id ORDER BY paid_at) 
FROM customer_collections
WHERE loan_id = '928573779228dc4d8ed1ce6f66e80c62'



ORDER BY paid_at

WITH
-- 1️⃣  Collections summary per loan
cc_data AS (
  SELECT
    loan_id,
    SUM(amount_paid) AS amount_paid,
    MAX(paid_at) AS paid_at
  FROM customer_collections
  GROUP BY 1
),

-- 2️⃣  Latest record per loan to detect activity
latest_status AS (
  SELECT DISTINCT ON (loan_id)
    loan_id,
    deleted_at,
    (deleted_at IS NULL) AS loan_active
  FROM customer_instalments
  ORDER BY loan_id, deleted_at DESC NULLS LAST
),

-- 3️⃣  Aggregate instalment + collection info
t_data AS (
  SELECT
    ci.loan_id,
    SUM(ci.amount_to_pay) AS amount_to_pay,
    SUM(ci.discount) AS discount,
    SUM(ci.amount_to_pay - ci.discount) - COALESCE(SUM(cc.amount_paid), 0) AS balance,
    MIN(ci.entered_at) AS entered_at,
    MIN(ci.created_at) AS created_at,
    ls.deleted_at,
    ls.loan_active,
    (SUM(ci.amount_to_pay - ci.discount) - COALESCE(SUM(cc.amount_paid), 0) >= 1) AS has_bal,
    (ls.loan_active
      AND (SUM(ci.amount_to_pay - ci.discount) - COALESCE(SUM(cc.amount_paid), 0) >= 1)) AS active,
    MAX(cc.paid_at) AS paid_at
  FROM customer_instalments ci
  LEFT JOIN cc_data cc USING (loan_id)
  LEFT JOIN latest_status ls USING (loan_id)
  GROUP BY ci.loan_id, ls.deleted_at, ls.loan_active
),

-- 4️⃣  Derive start/end dates per loan
t2_data AS (
  SELECT
    loan_id,
    loan_active,
    has_bal,
    paid_at,
    deleted_at,
    balance,
    active,
    LEAST(created_at, entered_at) AS start_at,
    CASE
      WHEN active THEN CURRENT_DATE
      ELSE GREATEST(COALESCE(deleted_at, paid_at), COALESCE(paid_at, deleted_at))
    END AS end_at
  FROM t_data
)

-- 5️⃣  Expand to one row per day of activity
SELECT
  loan_id,
  event_at::date
FROM t2_data,
LATERAL generate_series(start_at, end_at, interval '1 day') AS event_at;


SELECT * FROM customer_instalments



SELECT * FROM customer_collections

	SELECT
        ci.loan_id,
        amount_paid,
        CASE
            WHEN event_type = MIN(entered_at) OVER(PARTITION BY loan_id) THEN 'entered'
            WHEN event_type = MIN(created_at) OVER(PARTITION BY loan_id) THEN 'creation'
            WHEN event_type = MAX(cc.paid_at) OVER(PARTITION BY loan_id) AND balance_after = 0.0 THEN 'paid off'
            WHEN event_type = MAX(deleted_at) OVER(PARTITION BY loan_id) THEN 'deleted'
            ELSE 'payment'
        END AS event_type,
        SUM(amount_paid) OVER(PARTITION BY loan_id ORDER BY paid_at)
    FROM dfc cc
    LEFT JOIN dfi ci
    ON cc.loan_id = ci.loan_id
    ORDER BY ci.loan_id




	SELECT
        loan_id,
        amount_paid,
        CASE
            WHEN created_at = MIN(created_at) OVER(PARTITION BY loan_id) THEN 'creation'
            WHEN created_at = MAX(created_at) OVER(PARTITION BY loan_id) AND balance_after = 0.0 THEN 'completed'
            ELSE 'payment'
        END AS event_type,
        SUM(amount_paid) OVER(PARTITION BY loan_id ORDER BY paid_at)
    FROM customer_collections
    ORDER BY loan_id




SELECT * FROM customer_instalments
WHERE loan_id = '413b82ad8cfa7816bd10246a056faa84'

SELECT * FROM customer_collections


CREATE TABLE customer_instalments_sample AS
SELECT * FROM customer_instalments
LIMIT 1000

CREATE TABLE customer_collections_sample AS
SELECT * FROM customer_collections
LIMIT 1000

SELECT * FROM customer_instalments
DROP TABLE 	customer_instalments

select
  partner_id,
  loan_id,
  amount_to_pay,
  discount,
  amount_to_pay - discount - coalesce(cc.amount_paid, 0) as balance
from customer_instalments ci
cross join lateral (
  select
    sum(amount_paid) as amount_paid
  from customer_collections cc
  where cc.partner_id = ci.partner_id
    and cc.loan_id = ci.loan_id
) as cc

SELECT * FROM customer_collections_sample


SELECT
	partner_id,
	loan_id,
	amount_to_pay,
	discount,
	amount_to_pay - discount - COALESCE(cc.amount_paid, 0) as balance
FROM customer_instalments_sample ci
CROSS JOIN LATERAL(
	SELECT
		SUM(amount_paid) as amount_paid
	FROM customer_collections_sample cc
	WHERE ci.partner_id = cc.partner_id
	AND ci.loan_id = cc.loan_id
) as cc
WHERE loan_id = 'f58fa4341728e82d87e937aea3c63ad1'

SELECT
	ci.partner_id,
    ci.loan_id,
    ci.amount_to_pay,
    ci.discount,
    COALESCE(SUM(cc.amount_paid), 0) AS total_paid,
    ci.amount_to_pay - ci.discount - COALESCE(SUM(cc.amount_paid), 0) AS balance
  FROM customer_instalments_sample ci
  LEFT JOIN customer_collections_sample cc
    ON ci.partner_id = cc.partner_id
    AND ci.loan_id = cc.loan_id
GROUP BY 1,2,3,4
WHERE ci.loan_id = 'f58fa4341728e82d87e937aea3c63ad1'*/

/*#UPDATE
SELECT
  cc.loan_id,
  ci.amount_to_pay,
  ci.discount,
  COALESCE(SUM(cc.amount_paid), 0) AS paid,
  SUM(cc.amount_paid) OVER(PARTITION BY cc.loan_id ORDER BY paid_at) as total_paid,
  ci.amount_to_pay - ci.discount - COALESCE(SUM(cc.amount_paid) OVER(PARTITION BY cc.loan_id ORDER BY paid_at), 0) AS running_balance,
  CASE
    WHEN ci.deleted_at IS NOT NULL THEN 'deleted'
    WHEN ci.amount_to_pay - ci.discount - COALESCE(SUM(cc.amount_paid), 0) = 0 THEN 'paid off'
    WHEN ci.created_at IS NOT NULL THEN 'creation'
    WHEN ci.entered_at IS NOT NULL THEN 'entered'
    ELSE 'active'
  END AS event_type,
  MIN(ci.entered_at) AS entered_at,
  MIN(ci.created_at) AS created_at,
  MAX(cc.paid_at) AS last_payment_at,
  MAX(ci.deleted_at) AS deleted_at
FROM customer_instalments_sample ci
LEFT JOIN customer_collections_sample cc
  ON ci.partner_id = cc.partner_id
  AND ci.loan_id = cc.loan_id
GROUP BY
  cc.loan_id,
  ci.amount_to_pay,
  ci.discount,
  ci.entered_at,
  ci.created_at,
  cc.amount_paid,
  ci.deleted_at,
  cc.paid_at;
*/

/*SELECT 
	loan_id,
	paid_at,
	amount_paid,
	SUM(amount_paid) OVER(PARTITION BY loan_id ORDER BY paid_at) 
FROM customer_collections


#2nd orginal kind of
SELECT
	cc.loan_id,
	SUM(ci.amount_to_pay),
	SUM(ci.discount),
	
	--Total amount paid
	SUM(cc.amount_paid) OVER(PARTITION BY cc.loan_id ORDER BY paid_at) as total_paid,
	
	--Running balance(remaining)
	SUM(amount_to_pay - discount) - COALESCE(SUM(cc.amount_paid) OVER(PARTITION BY cc.loan_id ORDER BY paid_at), 0) AS running_balance,

	--Loan active status
	CASE
		WHEN deleted_at IS NULL THEN FALSE
		ELSE FALSE
	END AS active,

	--
	CASE
		WHEN ci.amount_to_pay - ci.discount - COALESCE(SUM(cc.amount_paid) OVER(PARTITION BY cc.loan_id ORDER BY paid_at), 0) > 0 THEN TRUE
		ELSE FALSE
	END AS has_balance, 

	--start date of the loan
	LEAST (ci.created_at, ci.entered_at) as start_date,
	
	--last date of the loan
	CASE
		WHEN ci.amount_to_pay - ci.discount - 
			COALESCE(SUM(cc.amount_paid) OVER(PARTITION BY cc.loan_id ORDER BY paid_at), 0) > 0 
			AND ci.deleted_at IS NULL THEN CURRENT_DATE
		ELSE GREATEST(ci.deleted_at, MAX(cc.paid_at)OVER(PARTITION BY cc.loan_id))
	END AS end_date,

	--event type
	CASE
		WHEN ci.deleted_at IS NOT NULL THEN 'deleted'
		WHEN ci.created_at = MIN(ci.created_at) OVER(PARTITION BY cc.loan_id) THEN 'creation'
		WHEN ci.amount_to_pay - ci.discount - 
			COALESCE(SUM(cc.amount_paid) OVER(PARTITION BY cc.loan_id ORDER BY paid_at), 0) = 0 
			AND cc.paid_at = MAX(cc.paid_at)OVER(PARTITION BY cc.loan_id) THEN 'paid off'
		ELSE 'payment'
	END AS event_type
FROM customer_instalments_sample ci 
LEFT JOIN customer_collections_sample cc
  ON ci.loan_id = cc.loan_id



/*MIN(ci.entered_at) AS entered_at,
	MIN(ci.created_at) AS created_at,
	MAX(cc.paid_at) AS last_payment_at,
	MAX(ci.deleted_at) AS deleted_at  */


SELECT * FROM customer_instalments
WHERE loan_id = '000029e77bd3b8579458b601d08f85f6'


SELECT
	cc.loan_id,
	SUM(ci.amount_to_pay),
	SUM(ci.discount),
	
	--Total amount paid
	SUM(cc.amount_paid) OVER(PARTITION BY cc.loan_id ORDER BY paid_at) as total_paid,
	
	--Running balance(remaining)
	SUM(amount_to_pay - discount) - COALESCE(SUM(cc.amount_paid) OVER(PARTITION BY cc.loan_id ORDER BY paid_at), 0) AS running_balance,

	--Loan active status
	CASE
		WHEN deleted_at IS NULL THEN FALSE
		ELSE FALSE
	END AS active,

	--
	CASE
		WHEN ci.amount_to_pay - ci.discount - COALESCE(SUM(cc.amount_paid) OVER(PARTITION BY cc.loan_id ORDER BY paid_at), 0) > 0 THEN TRUE
		ELSE FALSE
	END AS has_balance, 

	--start date of the loan
	LEAST (ci.created_at, ci.entered_at) as start_date,
	
	--last date of the loan
	CASE
		WHEN ci.amount_to_pay - ci.discount - 
			COALESCE(SUM(cc.amount_paid) OVER(PARTITION BY cc.loan_id ORDER BY paid_at), 0) > 0 
			AND ci.deleted_at IS NULL THEN CURRENT_DATE
		ELSE GREATEST(ci.deleted_at, MAX(cc.paid_at)OVER(PARTITION BY cc.loan_id))
	END AS end_date,

	--event type
	CASE
		WHEN ci.deleted_at IS NOT NULL THEN 'deleted'
		WHEN ci.created_at = MIN(ci.created_at) OVER(PARTITION BY cc.loan_id) THEN 'creation'
		WHEN ci.amount_to_pay - ci.discount - 
			COALESCE(SUM(cc.amount_paid) OVER(PARTITION BY cc.loan_id ORDER BY paid_at), 0) = 0 
			AND cc.paid_at = MAX(cc.paid_at)OVER(PARTITION BY cc.loan_id) THEN 'paid off'
		ELSE 'payment'
	END AS event_type
FROM customer_instalments_sample ci 
LEFT JOIN customer_collections_sample cc
  ON ci.loan_id = cc.loan_id




with cc_data as (
  select
    loan_id,
    sum(amount_paid) as amount_paid,
    max(paid_at) as paid_at
  from customer_collections cc
  group by 1
)
select
loan_id, 
sum(amount_to_pay) as amount_to_pay,
sum(discount) as discount,
sum(amount_to_pay - discount) - coalesce(sum(amount_paid), 0) as balance,
min(entered_at) as entered_at,
min(created_at) as created_at,
max(deleted_at) as deleted_at,
max(deleted_at is null) as loan_active,
(sum(amount_to_pay - discount) - coalesce(sum(amount_paid), 0) >= 1) as has_bal,
(max(deleted_at is null) and (sum(amount_to_pay - discount) - coalesce(sum(amount_paid), 0) >= 1)) as active,
max(paid_at) as paid_at
from customer_instalments
left join cc_data using(loan_id)
group by 1
*/


WITH cus_c as(SELECT
	loan_id,
	SUM(amount_paid) as amount_paid,
	MAX(paid_at) as paid_at
FROM customer_collections_sample cc
GROUP BY 1), 

loan_summary AS (
	SELECT
		loan_id,
		SUM(amount_to_pay) as amount_to_pay,
		SUM(discount) as discount,
		SUM(amount_to_pay - discount) - COALESCE(SUM(amount_paid), 0) as balance,
		MIN(entered_at) as entered_at,
		MIN(created_at) as created_at,
		MAX(paid_at) as paid_at,
		MAX(deleted_at) as deleted_at,
		(SUM(amount_to_pay - discount) - COALESCE(SUM(amount_paid), 0)) >= 1 as has_bal,
		MAX(deleted_at) is null as is_active,
		LEAST(MIN(created_at::timestamp), MIN(entered_at::timestamp)) as start_date,
		CASE
			WHEN MAX(deleted_at::timestamp) is null THEN CURRENT_DATE
			ELSE GREATEST (MAX(deleted_at::timestamp), MAX(paid_at::timestamp))
		END AS end_date
	FROM customer_instalments_sample
	LEFT JOIN cus_c USING (loan_id)
	GROUP BY 1
),

loan_dates AS (
	SELECT
		loan_id,
		generate_series(start_date::date, end_date::date, '1 day') as event_date
	FROM loan_summary
	WHERE is_active = TRUE
) 

--CRESTE TEMP TABLE 	
SELECT
	ld.loan_id,
	balance,
	has_bal,
	entered_at,
	created_at,
	deleted_at,
	paid_at,
	is_active,
	ls.start_date,
	ls.end_date, 
	ld.event_date
FROM loan_summary ls 
LEFT JOIN loan_dates ld USING (loan_id)
ORDER BY loan_id