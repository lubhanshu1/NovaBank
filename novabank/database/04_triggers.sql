-- ============================================================================
-- NovaBank - Database Triggers (04_triggers.sql)
-- DBMS Banking Management System Project
-- Ensures database-level constraints, audit logging, and automated integrity.
-- ============================================================================

USE novabank;

DELIMITER //

-- ----------------------------------------------------------------------------
-- Trigger: trg_accounts_before_update
-- Strict database-level constraint: Prevents balance from dropping below minimum balance
-- or executing balance modifications on FROZEN / CLOSED accounts.
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_accounts_before_update //
CREATE TRIGGER trg_accounts_before_update
BEFORE UPDATE ON accounts
FOR EACH ROW
BEGIN
    -- Check if account is frozen or closed
    IF OLD.status IN ('FROZEN', 'CLOSED') AND NEW.balance != OLD.balance THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Integrity Violation: Balance modifications are disallowed on FROZEN or CLOSED accounts.';
    END IF;

    -- Check minimum balance constraint
    IF NEW.balance < NEW.minimum_balance THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Integrity Violation: Balance cannot be less than the account minimum balance threshold.';
    END IF;
END //

-- ----------------------------------------------------------------------------
-- Trigger: trg_accounts_after_update
-- Automatically records an audit trail whenever an account's balance or status changes.
-- Stores structured JSON snapshots of old and new states.
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_accounts_after_update //
CREATE TRIGGER trg_accounts_after_update
AFTER UPDATE ON accounts
FOR EACH ROW
BEGIN
    DECLARE v_summary VARCHAR(255);

    IF OLD.balance != NEW.balance OR OLD.status != NEW.status THEN
        SET v_summary = CONCAT(
            'Account ', NEW.account_number, 
            ' | Bal: ₹', OLD.balance, ' -> ₹', NEW.balance,
            ' (Diff: ', IF(NEW.balance >= OLD.balance, '+', ''), ROUND(NEW.balance - OLD.balance, 2), ')',
            IF(OLD.status != NEW.status, CONCAT(' | Status: ', OLD.status, ' -> ', NEW.status), '')
        );

        INSERT INTO audit_logs (
            table_name, operation, record_id,
            old_values, new_values, changed_by, action_summary
        ) VALUES (
            'accounts', 'UPDATE', NEW.account_id,
            JSON_OBJECT(
                'account_number', OLD.account_number,
                'balance', OLD.balance,
                'status', OLD.status,
                'minimum_balance', OLD.minimum_balance
            ),
            JSON_OBJECT(
                'account_number', NEW.account_number,
                'balance', NEW.balance,
                'status', NEW.status,
                'minimum_balance', NEW.minimum_balance
            ),
            CURRENT_USER(),
            v_summary
        );
    END IF;
END //

-- ----------------------------------------------------------------------------
-- Trigger: trg_transactions_before_insert
-- Fallback trigger to ensure every transaction has a unique compliant reference code.
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_transactions_before_insert //
CREATE TRIGGER trg_transactions_before_insert
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
    IF NEW.reference_no IS NULL OR NEW.reference_no = '' THEN
        SET NEW.reference_no = CONCAT(
            'TXN-AUTO-',
            DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'), '-',
            LPAD(FLOOR(RAND() * 100000), 5, '0')
        );
    END IF;
END //

-- ----------------------------------------------------------------------------
-- Trigger: trg_transactions_after_insert
-- Captures transaction creation in audit log for compliance
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_transactions_after_insert //
CREATE TRIGGER trg_transactions_after_insert
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (
        table_name, operation, record_id,
        old_values, new_values, changed_by, action_summary
    ) VALUES (
        'transactions', 'INSERT', NEW.transaction_id,
        NULL,
        JSON_OBJECT(
            'reference_no', NEW.reference_no,
            'account_id', NEW.account_id,
            'type', NEW.transaction_type,
            'amount', NEW.amount,
            'channel', NEW.channel,
            'status', NEW.status
        ),
        CURRENT_USER(),
        CONCAT('Transaction ', NEW.reference_no, ' (', NEW.transaction_type, ' ₹', NEW.amount, ') recorded.')
    );
END //

-- ----------------------------------------------------------------------------
-- Trigger: trg_customers_after_insert
-- Audit log entry for customer onboarding
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_customers_after_insert //
CREATE TRIGGER trg_customers_after_insert
AFTER INSERT ON customers
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (
        table_name, operation, record_id,
        old_values, new_values, changed_by, action_summary
    ) VALUES (
        'customers', 'INSERT', NEW.customer_id,
        NULL,
        JSON_OBJECT(
            'customer_number', NEW.customer_number,
            'name', CONCAT(NEW.first_name, ' ', NEW.last_name),
            'email', NEW.email,
            'tier', NEW.customer_tier
        ),
        CURRENT_USER(),
        CONCAT('Customer onboarded: ', NEW.first_name, ' ', NEW.last_name, ' (', NEW.customer_number, ')')
    );
END //

-- ----------------------------------------------------------------------------
-- Trigger: trg_loans_after_insert
-- Audit log entry for loan origination
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_loans_after_insert //
CREATE TRIGGER trg_loans_after_insert
AFTER INSERT ON loans
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (
        table_name, operation, record_id,
        old_values, new_values, changed_by, action_summary
    ) VALUES (
        'loans', 'INSERT', NEW.loan_id,
        NULL,
        JSON_OBJECT(
            'loan_number', NEW.loan_number,
            'customer_id', NEW.customer_id,
            'principal', NEW.principal_amount,
            'term_months', NEW.term_months,
            'emi', NEW.monthly_emi
        ),
        CURRENT_USER(),
        CONCAT('Loan originated: ', NEW.loan_number, ' (₹', NEW.principal_amount, ' at ', NEW.interest_rate, '%)')
    );
END //

DELIMITER ;

