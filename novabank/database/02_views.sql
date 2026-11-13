-- ============================================================================
-- NovaBank - Database Views (02_views.sql)
-- DBMS Banking Management System Project
-- ============================================================================

USE novabank;

-- ----------------------------------------------------------------------------
-- View: vw_customer_account_summary
-- Aggregated customer profile with total balance across all open accounts
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_customer_account_summary;
CREATE VIEW vw_customer_account_summary AS
SELECT 
    c.customer_id,
    c.customer_number,
    CONCAT(c.first_name, ' ', c.last_name) AS full_name,
    c.email,
    c.phone,
    c.kyc_status,
    c.customer_tier,
    COUNT(a.account_id) AS total_accounts,
    COALESCE(SUM(CASE WHEN a.status = 'ACTIVE' THEN a.balance ELSE 0 END), 0.00) AS total_active_balance,
    COALESCE(SUM(a.balance), 0.00) AS total_aggregate_balance,
    b.branch_name AS primary_branch
FROM customers c
LEFT JOIN accounts a ON c.customer_id = a.customer_id
LEFT JOIN branches b ON a.branch_id = b.branch_id
GROUP BY c.customer_id, c.customer_number, full_name, c.email, c.phone, c.kyc_status, c.customer_tier, b.branch_name;

-- ----------------------------------------------------------------------------
-- View: vw_daily_transaction_metrics
-- Daily analytical breakdown of transaction volume, counts, and average values
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_daily_transaction_metrics;
CREATE VIEW vw_daily_transaction_metrics AS
SELECT 
    DATE(t.transaction_date) AS txn_date,
    t.transaction_type,
    t.channel,
    COUNT(t.transaction_id) AS transaction_count,
    SUM(t.amount) AS total_volume,
    ROUND(AVG(t.amount), 2) AS average_amount,
    MIN(t.amount) AS min_amount,
    MAX(t.amount) AS max_amount
FROM transactions t
WHERE t.status = 'COMPLETED'
GROUP BY DATE(t.transaction_date), t.transaction_type, t.channel;

-- ----------------------------------------------------------------------------
-- View: vw_high_risk_transactions
-- Compliance view flagging high-value, abnormal, or failed transfers
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_high_risk_transactions;
CREATE VIEW vw_high_risk_transactions AS
SELECT 
    t.transaction_id,
    t.reference_no,
    t.transaction_date,
    t.transaction_type,
    t.amount,
    t.status,
    t.channel,
    a.account_number,
    CONCAT(c.first_name, ' ', c.last_name) AS account_holder,
    c.customer_tier,
    CASE 
        WHEN t.status = 'FAILED' THEN 'FAILED_ATTEMPT'
        WHEN t.amount >= 500000.00 THEN 'LARGE_CASH_OR_TRANSFER_ALERT'
        WHEN t.amount >= 200000.00 THEN 'MODERATE_HIGH_VALUE'
        ELSE 'STANDARD_AUDIT'
    END AS risk_classification
FROM transactions t
JOIN accounts a ON t.account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE t.amount >= 200000.00 OR t.status = 'FAILED';

-- ----------------------------------------------------------------------------
-- View: vw_loan_portfolio_health
-- Portfolio risk analysis grouped by loan category
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_loan_portfolio_health;
CREATE VIEW vw_loan_portfolio_health AS
SELECT 
    l.loan_type,
    COUNT(l.loan_id) AS total_loans,
    SUM(CASE WHEN l.status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_loans,
    SUM(CASE WHEN l.status = 'PAID_OFF' THEN 1 ELSE 0 END) AS paid_off_loans,
    SUM(CASE WHEN l.status = 'DEFAULTED' THEN 1 ELSE 0 END) AS defaulted_loans,
    SUM(l.principal_amount) AS total_principal_disbursed,
    SUM(l.outstanding_balance) AS total_outstanding_balance,
    ROUND(AVG(l.interest_rate), 2) AS avg_interest_rate,
    ROUND(SUM(l.monthly_emi), 2) AS total_monthly_expected_inflow
FROM loans l
GROUP BY l.loan_type;

-- ----------------------------------------------------------------------------
-- View: vw_branch_performance
-- Branch metrics including customer base, deposits, and loan commitments
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_branch_performance;
CREATE VIEW vw_branch_performance AS
SELECT 
    b.branch_id,
    b.branch_code,
    b.branch_name,
    b.city,
    b.state,
    COUNT(DISTINCT a.customer_id) AS total_customers,
    COUNT(a.account_id) AS total_accounts,
    COALESCE(SUM(a.balance), 0.00) AS total_deposits,
    COALESCE(SUM(l.principal_amount), 0.00) AS total_loans_issued
FROM branches b
LEFT JOIN accounts a ON b.branch_id = a.branch_id
LEFT JOIN loans l ON a.account_id = l.account_id
GROUP BY b.branch_id, b.branch_code, b.branch_name, b.city, b.state;

-- ----------------------------------------------------------------------------
-- View: vw_audit_trail_recent
-- Real-time audit log view showing recent system modifications
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_audit_trail_recent;
CREATE VIEW vw_audit_trail_recent AS
SELECT 
    audit_id,
    table_name,
    operation,
    record_id,
    action_summary,
    changed_by,
    old_values,
    new_values,
    timestamp
FROM audit_logs
ORDER BY timestamp DESC, audit_id DESC
LIMIT 100;

