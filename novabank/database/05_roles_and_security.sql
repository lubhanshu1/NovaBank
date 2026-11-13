-- ============================================================================
-- NovaBank - Roles and Security Privileges (05_roles_and_security.sql)
-- DBMS Banking Management System Project
-- MySQL 8.x Role-Based Access Control (RBAC) & Principle of Least Privilege
-- ============================================================================

USE novabank;

-- ----------------------------------------------------------------------------
-- Create Application User
-- ----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'novabank_app'@'localhost' IDENTIFIED BY 'NovaBank_App_2026!';
CREATE USER IF NOT EXISTS 'novabank_app'@'127.0.0.1' IDENTIFIED BY 'NovaBank_App_2026!';
CREATE USER IF NOT EXISTS 'novabank_app'@'%' IDENTIFIED BY 'NovaBank_App_2026!';

-- ----------------------------------------------------------------------------
-- Create Roles
-- ----------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS 'novabank_admin_role';
CREATE ROLE IF NOT EXISTS 'novabank_teller_role';
CREATE ROLE IF NOT EXISTS 'novabank_auditor_role';

-- ----------------------------------------------------------------------------
-- Grant Privileges to Roles
-- ----------------------------------------------------------------------------
-- 1. Admin Role: Full administration on novabank database
GRANT ALL PRIVILEGES ON novabank.* TO 'novabank_admin_role' WITH GRANT OPTION;

-- 2. Teller Role: Day-to-day branch operations (Least Privilege)
-- Can read all banking entities, execute financial procedures, cannot drop/alter tables
GRANT SELECT ON novabank.* TO 'novabank_teller_role';
GRANT EXECUTE ON PROCEDURE novabank.sp_transfer_funds TO 'novabank_teller_role';
GRANT EXECUTE ON PROCEDURE novabank.sp_deposit_funds TO 'novabank_teller_role';
GRANT EXECUTE ON PROCEDURE novabank.sp_withdraw_funds TO 'novabank_teller_role';
GRANT EXECUTE ON PROCEDURE novabank.sp_open_account TO 'novabank_teller_role';
GRANT INSERT ON novabank.transactions TO 'novabank_teller_role';
GRANT INSERT, UPDATE ON novabank.beneficiaries TO 'novabank_teller_role';

-- 3. Auditor Role: Compliance and inspection (Strictly Read-Only)
-- Cannot modify accounts or transactions; access to views and audit trail
GRANT SELECT ON novabank.audit_logs TO 'novabank_auditor_role';
GRANT SELECT ON novabank.transactions TO 'novabank_auditor_role';
GRANT SELECT ON novabank.accounts TO 'novabank_auditor_role';
GRANT SELECT ON novabank.customers TO 'novabank_auditor_role';
GRANT SELECT ON novabank.loans TO 'novabank_auditor_role';
GRANT SELECT ON novabank.vw_customer_account_summary TO 'novabank_auditor_role';
GRANT SELECT ON novabank.vw_daily_transaction_metrics TO 'novabank_auditor_role';
GRANT SELECT ON novabank.vw_high_risk_transactions TO 'novabank_auditor_role';
GRANT SELECT ON novabank.vw_loan_portfolio_health TO 'novabank_auditor_role';
GRANT SELECT ON novabank.vw_branch_performance TO 'novabank_auditor_role';
GRANT SELECT ON novabank.vw_audit_trail_recent TO 'novabank_auditor_role';

-- ----------------------------------------------------------------------------
-- Grant Base Privileges to Application User novabank_app
-- ----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON novabank.* TO 'novabank_app'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON novabank.* TO 'novabank_app'@'127.0.0.1';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON novabank.* TO 'novabank_app'@'%';

-- Grant roles to application user so it can demonstrate RBAC role-switching
GRANT 'novabank_admin_role', 'novabank_teller_role', 'novabank_auditor_role' 
   TO 'novabank_app'@'localhost', 'novabank_app'@'127.0.0.1', 'novabank_app'@'%';

-- Grant default role
SET DEFAULT ROLE 'novabank_admin_role' TO 'novabank_app'@'localhost', 'novabank_app'@'127.0.0.1', 'novabank_app'@'%';

FLUSH PRIVILEGES;

