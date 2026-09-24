DROP TABLE IF EXISTS loan_features;

CREATE TABLE loan_features AS
WITH completed AS (
    SELECT
        r.*,
        TO_DATE(NULLIF(r.issue_d, ''), 'Mon-YYYY')          AS issue_date,
        TO_DATE(NULLIF(r.earliest_cr_line, ''), 'Mon-YYYY') AS first_credit_date
    FROM loans_raw r
    WHERE r.loan_status IN (
        'Fully Paid',
        'Charged Off',
        'Default',
        'Does not meet the credit policy. Status:Fully Paid',
        'Does not meet the credit policy. Status:Charged Off'
    )
)
SELECT
    id,
    issue_date,
    EXTRACT(YEAR FROM issue_date)::INT AS issue_year,
    CASE WHEN loan_status IN ('Charged Off', 'Default',
              'Does not meet the credit policy. Status:Charged Off')
         THEN 1 ELSE 0 END AS defaulted,
    loan_amnt,
    funded_amnt,
    int_rate,
    grade,
    sub_grade,
    home_ownership,
    verification_status,
    purpose,
    addr_state,
    delinq_2yrs,
    inq_last_6mths,
    pub_rec,
    pub_rec_bankruptcies,
    mort_acc,
    revol_bal,
    NULLIF(REGEXP_REPLACE(term, '\D', '', 'g'), '')::INT AS term_months,
    CASE WHEN emp_length IS NULL OR emp_length IN ('', 'n/a') THEN NULL
         WHEN emp_length LIKE '<%' THEN 0
         ELSE NULLIF(REGEXP_REPLACE(emp_length, '\D', '', 'g'), '')::INT
    END AS emp_years,
    (fico_range_low + fico_range_high) / 2.0 AS fico_avg,
    LN(COALESCE(annual_inc, 0) + 1) AS log_annual_inc,
    CASE WHEN dti < 0 OR dti > 100 THEN NULL ELSE dti END AS dti_clean,
    (installment * 12) / NULLIF(annual_inc, 0) AS payment_to_income,
    loan_amnt / NULLIF(annual_inc, 0) AS loan_to_income,
    (issue_date - first_credit_date) / 365.25 AS credit_history_years,
    LEAST(revol_util, 150) AS revol_util_clean,
    open_acc::NUMERIC / NULLIF(total_acc, 0) AS open_acc_ratio,
    CASE WHEN delinq_2yrs > 0 OR pub_rec > 0 THEN 1 ELSE 0 END AS any_derog,
    CASE WHEN inq_last_6mths >= 2 THEN 1 ELSE 0 END AS recent_inquiries_flag,
    CASE WHEN mort_acc > 0 THEN 1 ELSE 0 END AS has_mortgage,
    CASE WHEN revol_util > 80 THEN 1 ELSE 0 END AS high_utilization_flag,
    CASE WHEN verification_status = 'Not Verified' THEN 0 ELSE 1 END AS income_verified,
    CASE WHEN loan_status IN ('Charged Off', 'Default',
              'Does not meet the credit policy. Status:Charged Off')
         THEN GREATEST(funded_amnt - total_rec_prncp - recoveries, 0)
         ELSE 0 END AS loss_amount
FROM completed;

SELECT COUNT(*) AS loans, ROUND(AVG(defaulted), 4) AS default_rate
FROM loan_features;