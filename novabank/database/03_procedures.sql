-- ============================================================================
-- NovaBank - Stored Procedures (03_procedures.sql)
-- DBMS Banking Management System Project
-- All core financial business logic lives inside MySQL stored procedures.
-- ============================================================================

USE novabank;

DELIMITER //

-- ----------------------------------------------------------------------------
-- Procedure: sp_transfer_funds
-- Atomic fund transfer with deterministic row locking to prevent deadlocks,
-- balance verification, minimum balance enforcement, and transaction logging.
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_transfer_funds //
CREATE PROCEDURE sp_transfer_funds (
    IN  p_from_acc_no   VARCHAR(20),
    IN  p_to_acc_no     VARCHAR(20),
    IN  p_amount        DECIMAL(15, 2),
    IN  p_description   VARCHAR(255),
    IN  p_channel       VARCHAR(20),
    OUT p_status        VARCHAR(20),
    OUT p_message       VARCHAR(255),
    OUT p_ref_no        VARCHAR(40)
)
proc_label: BEGIN
    DECLARE v_from_id       INT;
    DECLARE v_to_id         INT;
    DECLARE v_from_bal      DECIMAL(15, 2);
    DECLARE v_to_bal        DECIMAL(15, 2);
    DECLARE v_from_min_bal  DECIMAL(15, 2);
    DECLARE v_from_status   VARCHAR(20);
    DECLARE v_to_status     VARCHAR(20);
    DECLARE v_ref_out       VARCHAR(40);
    DECLARE v_ref_in        VARCHAR(40);
    DECLARE v_time_tag      VARCHAR(20);

    -- Exception handler with automatic rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = 'Database error occurred during fund transfer. Transaction rolled back.';
        SET p_ref_no  = NULL;
    END;

    -- Basic validation
    IF p_amount <= 0.00 THEN
        SET p_status  = 'FAILED';
        SET p_message = 'Transfer amount must be strictly greater than zero.';
        SET p_ref_no  = NULL;
        LEAVE proc_label;
    END IF;

    IF p_from_acc_no = p_to_acc_no THEN
        SET p_status  = 'FAILED';
        SET p_message = 'Sender and recipient accounts cannot be the same.';
        SET p_ref_no  = NULL;
        LEAVE proc_label;
    END IF;

    IF p_channel IS NULL OR p_channel = '' THEN
        SET p_channel = 'ONLINE';
    END IF;

    -- Generate banking reference numbers
    SET v_time_tag = DATE_FORMAT(NOW(), '%Y%m%d%H%i%s');
    SET v_ref_out  = CONCAT('TXN-TRF-', v_time_tag, '-', LPAD(FLOOR(RAND() * 100000), 5, '0'));
    SET v_ref_in   = CONCAT('TXN-RCV-', v_time_tag, '-', LPAD(FLOOR(RAND() * 100000), 5, '0'));

    START TRANSACTION;

    -- Retrieve IDs first without locks to establish deterministic lock order
    SELECT account_id, status, minimum_balance 
      INTO v_from_id, v_from_status, v_from_min_bal
      FROM accounts 
     WHERE account_number = p_from_acc_no;

    SELECT account_id, status 
      INTO v_to_id, v_to_status
      FROM accounts 
     WHERE account_number = p_to_acc_no;

    IF v_from_id IS NULL THEN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = CONCAT('Source account ', p_from_acc_no, ' does not exist.');
        SET p_ref_no  = NULL;
        LEAVE proc_label;
    END IF;

    IF v_to_id IS NULL THEN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = CONCAT('Destination account ', p_to_acc_no, ' does not exist.');
        SET p_ref_no  = NULL;
        LEAVE proc_label;
    END IF;

    IF v_from_status != 'ACTIVE' THEN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = CONCAT('Source account is currently ', v_from_status, ' and cannot initiate transfers.');
        SET p_ref_no  = NULL;
        LEAVE proc_label;
    END IF;

    IF v_to_status != 'ACTIVE' THEN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = CONCAT('Destination account is currently ', v_to_status, ' and cannot accept transfers.');
        SET p_ref_no  = NULL;
        LEAVE proc_label;
    END IF;

    -- Row Locking in deterministic order (smaller ID first) to eliminate deadlock
    IF v_from_id < v_to_id THEN
        SELECT balance INTO v_from_bal FROM accounts WHERE account_id = v_from_id FOR UPDATE;
        SELECT balance INTO v_to_bal   FROM accounts WHERE account_id = v_to_id   FOR UPDATE;
    ELSE
        SELECT balance INTO v_to_bal   FROM accounts WHERE account_id = v_to_id   FOR UPDATE;
        SELECT balance INTO v_from_bal FROM accounts WHERE account_id = v_from_id FOR UPDATE;
    END IF;

    -- Enforce balance and minimum balance constraints
    IF (v_from_bal - p_amount) < v_from_min_bal THEN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = CONCAT('Insufficient funds. Available: ₹', v_from_bal, 
                               ', Required: ₹', p_amount, 
                               ' (Minimum balance threshold: ₹', v_from_min_bal, ').');
        SET p_ref_no  = NULL;
        LEAVE proc_label;
    END IF;

    -- Perform debit
    UPDATE accounts 
       SET balance = balance - p_amount,
           updated_at = CURRENT_TIMESTAMP
     WHERE account_id = v_from_id;

    -- Record sender transaction
    INSERT INTO transactions (
        reference_no, account_id, transaction_type, amount,
        balance_before, balance_after, related_account_id,
        status, channel, description
    ) VALUES (
        v_ref_out, v_from_id, 'TRANSFER_OUT', p_amount,
        v_from_bal, (v_from_bal - p_amount), v_to_id,
        'COMPLETED', p_channel, 
        COALESCE(p_description, CONCAT('Transfer to account ', p_to_acc_no))
    );

    -- Perform credit
    UPDATE accounts 
       SET balance = balance + p_amount,
           updated_at = CURRENT_TIMESTAMP
     WHERE account_id = v_to_id;

    -- Record recipient transaction
    INSERT INTO transactions (
        reference_no, account_id, transaction_type, amount,
        balance_before, balance_after, related_account_id,
        status, channel, description
    ) VALUES (
        v_ref_in, v_to_id, 'TRANSFER_IN', p_amount,
        v_to_bal, (v_to_bal + p_amount), v_from_id,
        'COMPLETED', p_channel, 
        COALESCE(p_description, CONCAT('Transfer received from account ', p_from_acc_no))
    );

    COMMIT;

    SET p_status  = 'SUCCESS';
    SET p_message = CONCAT('Successfully transferred ₹', p_amount, ' to ', p_to_acc_no, '.');
    SET p_ref_no  = v_ref_out;
END //

-- ----------------------------------------------------------------------------
-- Procedure: sp_deposit_funds
-- Atomic cash/electronic deposit into an account
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_deposit_funds //
CREATE PROCEDURE sp_deposit_funds (
    IN  p_account_no  VARCHAR(20),
    IN  p_amount      DECIMAL(15, 2),
    IN  p_description VARCHAR(255),
    IN  p_channel     VARCHAR(20),
    OUT p_status      VARCHAR(20),
    OUT p_message     VARCHAR(255),
    OUT p_ref_no      VARCHAR(40)
)
proc_label: BEGIN
    DECLARE v_account_id INT;
    DECLARE v_cur_balance DECIMAL(15, 2);
    DECLARE v_acc_status VARCHAR(20);
    DECLARE v_ref VARCHAR(40);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = 'Database error occurred during deposit.';
        SET p_ref_no  = NULL;
    END;

    IF p_amount <= 0.00 THEN
        SET p_status  = 'FAILED';
        SET p_message = 'Deposit amount must be strictly positive.';
        SET p_ref_no  = NULL;
        LEAVE proc_label;
    END IF;

    IF p_channel IS NULL OR p_channel = '' THEN
        SET p_channel = 'ONLINE';
    END IF;

    SET v_ref = CONCAT('TXN-DEP-', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'), '-', LPAD(FLOOR(RAND() * 100000), 5, '0'));

    START TRANSACTION;

    SELECT account_id, balance, status 
      INTO v_account_id, v_cur_balance, v_acc_status
      FROM accounts
     WHERE account_number = p_account_no
       FOR UPDATE;

    IF v_account_id IS NULL THEN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = CONCAT('Account ', p_account_no, ' does not exist.');
        SET p_ref_no  = NULL;
        LEAVE proc_label;
    END IF;

    IF v_acc_status != 'ACTIVE' THEN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = CONCAT('Account is ', v_acc_status, ' and cannot accept deposits.');
        SET p_ref_no  = NULL;
        LEAVE proc_label;
    END IF;

    UPDATE accounts 
       SET balance = balance + p_amount,
           updated_at = CURRENT_TIMESTAMP
     WHERE account_id = v_account_id;

    INSERT INTO transactions (
        reference_no, account_id, transaction_type, amount,
        balance_before, balance_after, status, channel, description
    ) VALUES (
        v_ref, v_account_id, 'DEPOSIT', p_amount,
        v_cur_balance, (v_cur_balance + p_amount), 'COMPLETED', p_channel,
        COALESCE(p_description, 'Cash / Electronic Deposit')
    );

    COMMIT;

    SET p_status  = 'SUCCESS';
    SET p_message = CONCAT('Successfully deposited ₹', p_amount, ' into account ', p_account_no, '.');
    SET p_ref_no  = v_ref;
END //

-- ----------------------------------------------------------------------------
-- Procedure: sp_withdraw_funds
-- Atomic cash/electronic withdrawal enforcing minimum balance rules
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_withdraw_funds //
CREATE PROCEDURE sp_withdraw_funds (
    IN  p_account_no  VARCHAR(20),
    IN  p_amount      DECIMAL(15, 2),
    IN  p_description VARCHAR(255),
    IN  p_channel     VARCHAR(20),
    OUT p_status      VARCHAR(20),
    OUT p_message     VARCHAR(255),
    OUT p_ref_no      VARCHAR(40)
)
proc_label: BEGIN
    DECLARE v_account_id INT;
    DECLARE v_cur_balance DECIMAL(15, 2);
    DECLARE v_min_balance DECIMAL(15, 2);
    DECLARE v_acc_status VARCHAR(20);
    DECLARE v_ref VARCHAR(40);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = 'Database error occurred during withdrawal.';
        SET p_ref_no  = NULL;
    END;

    IF p_amount <= 0.00 THEN
        SET p_status  = 'FAILED';
        SET p_message = 'Withdrawal amount must be strictly positive.';
        SET p_ref_no  = NULL;
        LEAVE proc_label;
    END IF;

    IF p_channel IS NULL OR p_channel = '' THEN
        SET p_channel = 'ATM';
    END IF;

    SET v_ref = CONCAT('TXN-WTH-', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'), '-', LPAD(FLOOR(RAND() * 100000), 5, '0'));

    START TRANSACTION;

    SELECT account_id, balance, minimum_balance, status 
      INTO v_account_id, v_cur_balance, v_min_balance, v_acc_status
      FROM accounts
     WHERE account_number = p_account_no
       FOR UPDATE;

    IF v_account_id IS NULL THEN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = CONCAT('Account ', p_account_no, ' does not exist.');
        SET p_ref_no  = NULL;
        LEAVE proc_label;
    END IF;

    IF v_acc_status != 'ACTIVE' THEN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = CONCAT('Account is ', v_acc_status, ' and cannot execute withdrawals.');
        SET p_ref_no  = NULL;
        LEAVE proc_label;
    END IF;

    IF (v_cur_balance - p_amount) < v_min_balance THEN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = CONCAT('Insufficient funds. Current balance: ₹', v_cur_balance, 
                               ', Minimum required balance: ₹', v_min_balance, '.');
        SET p_ref_no  = NULL;
        LEAVE proc_label;
    END IF;

    UPDATE accounts 
       SET balance = balance - p_amount,
           updated_at = CURRENT_TIMESTAMP
     WHERE account_id = v_account_id;

    INSERT INTO transactions (
        reference_no, account_id, transaction_type, amount,
        balance_before, balance_after, status, channel, description
    ) VALUES (
        v_ref, v_account_id, 'WITHDRAWAL', p_amount,
        v_cur_balance, (v_cur_balance - p_amount), 'COMPLETED', p_channel,
        COALESCE(p_description, 'Cash / Electronic Withdrawal')
    );

    COMMIT;

    SET p_status  = 'SUCCESS';
    SET p_message = CONCAT('Successfully withdrew ₹', p_amount, ' from account ', p_account_no, '.');
    SET p_ref_no  = v_ref;
END //

-- ----------------------------------------------------------------------------
-- Procedure: sp_open_account
-- Creates a new bank account with unique account number generation and initial deposit
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_open_account //
CREATE PROCEDURE sp_open_account (
    IN  p_customer_id    INT,
    IN  p_branch_id      INT,
    IN  p_account_type   VARCHAR(20),
    IN  p_initial_deposit DECIMAL(15, 2),
    IN  p_interest_rate  DECIMAL(5, 2),
    IN  p_min_balance    DECIMAL(15, 2),
    OUT p_account_no     VARCHAR(20),
    OUT p_status         VARCHAR(20),
    OUT p_message        VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_new_account_no VARCHAR(20);
    DECLARE v_new_account_id INT;
    DECLARE v_ref VARCHAR(40);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status     = 'FAILED';
        SET p_message    = 'Database error occurred during account opening.';
        SET p_account_no = NULL;
    END;

    IF p_initial_deposit < p_min_balance THEN
        SET p_status     = 'FAILED';
        SET p_message    = CONCAT('Initial deposit (₹', p_initial_deposit, ') cannot be less than minimum balance (₹', p_min_balance, ').');
        SET p_account_no = NULL;
        LEAVE proc_label;
    END IF;

    -- Generate a distinct 10-digit account number starting with branch or type code
    SET v_new_account_no = CONCAT('10', LPAD(p_branch_id, 2, '0'), LPAD(FLOOR(RAND() * 1000000), 6, '0'));

    START TRANSACTION;

    INSERT INTO accounts (
        account_number, customer_id, branch_id, account_type,
        balance, minimum_balance, interest_rate, status, opened_date
    ) VALUES (
        v_new_account_no, p_customer_id, p_branch_id, p_account_type,
        p_initial_deposit, p_min_balance, p_interest_rate, 'ACTIVE', CURDATE()
    );

    SET v_new_account_id = LAST_INSERT_ID();

    -- Record initial opening deposit
    IF p_initial_deposit > 0.00 THEN
        SET v_ref = CONCAT('TXN-OPN-', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'), '-', LPAD(FLOOR(RAND() * 10000), 4, '0'));
        INSERT INTO transactions (
            reference_no, account_id, transaction_type, amount,
            balance_before, balance_after, status, channel, description
        ) VALUES (
            v_ref, v_new_account_id, 'DEPOSIT', p_initial_deposit,
            0.00, p_initial_deposit, 'COMPLETED', 'BRANCH', 'Initial Opening Deposit'
        );
    END IF;

    COMMIT;

    SET p_account_no = v_new_account_no;
    SET p_status     = 'SUCCESS';
    SET p_message    = CONCAT('Account ', v_new_account_no, ' created successfully.');
END //

-- ----------------------------------------------------------------------------
-- Procedure: sp_apply_loan
-- Calculates EMI using the banking financial formula and disburses funds
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_apply_loan //
CREATE PROCEDURE sp_apply_loan (
    IN  p_customer_id   INT,
    IN  p_account_id    INT,
    IN  p_loan_type     VARCHAR(20),
    IN  p_principal     DECIMAL(15, 2),
    IN  p_term_months   INT,
    IN  p_interest_rate DECIMAL(5, 2),
    OUT p_loan_id       INT,
    OUT p_monthly_emi   DECIMAL(15, 2),
    OUT p_status        VARCHAR(20),
    OUT p_message       VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_monthly_rate  DOUBLE;
    DECLARE v_factor        DOUBLE;
    DECLARE v_calc_emi      DECIMAL(15, 2);
    DECLARE v_loan_num      VARCHAR(20);
    DECLARE v_cur_balance   DECIMAL(15, 2);
    DECLARE v_ref           VARCHAR(40);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status      = 'FAILED';
        SET p_message     = 'Database error occurred during loan origination.';
        SET p_loan_id     = NULL;
        SET p_monthly_emi = 0.00;
    END;

    IF p_principal <= 0 OR p_term_months <= 0 THEN
        SET p_status      = 'FAILED';
        SET p_message     = 'Principal amount and term months must be strictly positive.';
        SET p_loan_id     = NULL;
        SET p_monthly_emi = 0.00;
        LEAVE proc_label;
    END IF;

    -- Monthly interest rate r = R / 12 / 100
    SET v_monthly_rate = (p_interest_rate / 12.0) / 100.0;
    IF v_monthly_rate > 0.0 THEN
        SET v_factor = POW(1.0 + v_monthly_rate, p_term_months);
        SET v_calc_emi = ROUND(p_principal * (v_monthly_rate * v_factor) / (v_factor - 1.0), 2);
    ELSE
        SET v_calc_emi = ROUND(p_principal / p_term_months, 2);
    END IF;

    SET v_loan_num = CONCAT('LN-', DATE_FORMAT(NOW(), '%y%m'), '-', LPAD(FLOOR(RAND() * 100000), 5, '0'));

    START TRANSACTION;

    SELECT balance INTO v_cur_balance FROM accounts WHERE account_id = p_account_id FOR UPDATE;

    INSERT INTO loans (
        loan_number, customer_id, account_id, loan_type,
        principal_amount, interest_rate, term_months, monthly_emi,
        outstanding_balance, status, start_date, end_date
    ) VALUES (
        v_loan_num, p_customer_id, p_account_id, p_loan_type,
        p_principal, p_interest_rate, p_term_months, v_calc_emi,
        p_principal, 'ACTIVE', CURDATE(), DATE_ADD(CURDATE(), INTERVAL p_term_months MONTH)
    );

    SET p_loan_id = LAST_INSERT_ID();

    -- Disburse principal into designated account
    UPDATE accounts 
       SET balance = balance + p_principal,
           updated_at = CURRENT_TIMESTAMP
     WHERE account_id = p_account_id;

    SET v_ref = CONCAT('TXN-LN-', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'), '-', LPAD(FLOOR(RAND() * 10000), 4, '0'));

    INSERT INTO transactions (
        reference_no, account_id, transaction_type, amount,
        balance_before, balance_after, status, channel, description
    ) VALUES (
        v_ref, p_account_id, 'LOAN_DISBURSEMENT', p_principal,
        v_cur_balance, (v_cur_balance + p_principal), 'COMPLETED', 'SYSTEM',
        CONCAT('Disbursement for Loan #', v_loan_num)
    );

    COMMIT;

    SET p_monthly_emi = v_calc_emi;
    SET p_status      = 'SUCCESS';
    SET p_message     = CONCAT('Loan approved and disbursed. Monthly EMI: ₹', v_calc_emi);
END //

-- ----------------------------------------------------------------------------
-- Procedure: sp_pay_loan_installment
-- Amortized loan repayment splitting payment into interest & principal
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_pay_loan_installment //
CREATE PROCEDURE sp_pay_loan_installment (
    IN  p_loan_id        INT,
    IN  p_from_acc_no    VARCHAR(20),
    OUT p_status         VARCHAR(20),
    OUT p_message        VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_account_id    INT;
    DECLARE v_acc_bal       DECIMAL(15, 2);
    DECLARE v_min_bal       DECIMAL(15, 2);
    DECLARE v_emi           DECIMAL(15, 2);
    DECLARE v_outstanding   DECIMAL(15, 2);
    DECLARE v_interest_rate DECIMAL(5, 2);
    DECLARE v_interest_part DECIMAL(15, 2);
    DECLARE v_principal_part DECIMAL(15, 2);
    DECLARE v_pay_count     INT;
    DECLARE v_ref           VARCHAR(40);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = 'Database error occurred during loan payment.';
    END;

    START TRANSACTION;

    SELECT account_id, balance, minimum_balance 
      INTO v_account_id, v_acc_bal, v_min_bal
      FROM accounts 
     WHERE account_number = p_from_acc_no 
       FOR UPDATE;

    SELECT monthly_emi, outstanding_balance, interest_rate 
      INTO v_emi, v_outstanding, v_interest_rate
      FROM loans 
     WHERE loan_id = p_loan_id AND status = 'ACTIVE'
       FOR UPDATE;

    IF v_account_id IS NULL THEN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = 'Payment account not found.';
        LEAVE proc_label;
    END IF;

    IF v_outstanding IS NULL THEN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = 'Active loan not found or already paid off.';
        LEAVE proc_label;
    END IF;

    IF (v_acc_bal - v_emi) < v_min_bal THEN
        ROLLBACK;
        SET p_status  = 'FAILED';
        SET p_message = CONCAT('Insufficient balance (₹', v_acc_bal, ') to pay monthly EMI (₹', v_emi, ').');
        LEAVE proc_label;
    END IF;

    -- Monthly interest component
    SET v_interest_part = ROUND(v_outstanding * (v_interest_rate / 12.0 / 100.0), 2);
    IF v_interest_part > v_emi THEN
        SET v_interest_part = v_emi;
    END IF;
    SET v_principal_part = v_emi - v_interest_part;

    IF v_principal_part > v_outstanding THEN
        SET v_principal_part = v_outstanding;
    END IF;

    -- Deduct from account
    UPDATE accounts 
       SET balance = balance - v_emi,
           updated_at = CURRENT_TIMESTAMP
     WHERE account_id = v_account_id;

    -- Update loan outstanding balance
    UPDATE loans 
       SET outstanding_balance = GREATEST(0.00, outstanding_balance - v_principal_part),
           status = CASE WHEN outstanding_balance - v_principal_part <= 0 THEN 'PAID_OFF' ELSE status END
     WHERE loan_id = p_loan_id;

    SELECT COUNT(*) + 1 INTO v_pay_count FROM loan_payments WHERE loan_id = p_loan_id;

    INSERT INTO loan_payments (
        loan_id, payment_number, payment_amount,
        principal_component, interest_component, status
    ) VALUES (
        p_loan_id, v_pay_count, v_emi,
        v_principal_part, v_interest_part, 'COMPLETED'
    );

    SET v_ref = CONCAT('TXN-LPY-', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'), '-', LPAD(FLOOR(RAND() * 10000), 4, '0'));

    INSERT INTO transactions (
        reference_no, account_id, transaction_type, amount,
        balance_before, balance_after, status, channel, description
    ) VALUES (
        v_ref, v_account_id, 'LOAN_REPAYMENT', v_emi,
        v_acc_bal, (v_acc_bal - v_emi), 'COMPLETED', 'ONLINE',
        CONCAT('EMI Payment for Loan ID ', p_loan_id)
    );

    COMMIT;

    SET p_status  = 'SUCCESS';
    SET p_message = CONCAT('EMI of ₹', v_emi, ' processed. Remaining principal: ₹', GREATEST(0.00, v_outstanding - v_principal_part));
END //

-- ----------------------------------------------------------------------------
-- Procedure: sp_monthly_interest_accrual
-- Demonstrates CURSOR iteration in MySQL Stored Procedures.
-- Loops through all active SAVINGS accounts and applies monthly interest.
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_monthly_interest_accrual //
CREATE PROCEDURE sp_monthly_interest_accrual (
    OUT p_processed_count INT,
    OUT p_total_interest  DECIMAL(15, 2)
)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_acc_id INT;
    DECLARE v_balance DECIMAL(15, 2);
    DECLARE v_rate DECIMAL(5, 2);
    DECLARE v_interest DECIMAL(15, 2);
    DECLARE v_ref VARCHAR(40);

    -- Cursor definition
    DECLARE cur_savings CURSOR FOR 
        SELECT account_id, balance, interest_rate 
          FROM accounts 
         WHERE account_type = 'SAVINGS' AND status = 'ACTIVE' AND balance > 0;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    SET p_processed_count = 0;
    SET p_total_interest = 0.00;

    OPEN cur_savings;

    acc_loop: LOOP
        FETCH cur_savings INTO v_acc_id, v_balance, v_rate;
        IF done THEN
            LEAVE acc_loop;
        END IF;

        -- Monthly interest calculation: (Balance * Rate) / 12 / 100
        SET v_interest = ROUND((v_balance * v_rate) / 1200.0, 2);

        IF v_interest > 0.00 THEN
            UPDATE accounts 
               SET balance = balance + v_interest,
                   updated_at = CURRENT_TIMESTAMP
             WHERE account_id = v_acc_id;

            SET v_ref = CONCAT('TXN-INT-', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'), '-', LPAD(FLOOR(RAND() * 10000), 4, '0'));

            INSERT INTO transactions (
                reference_no, account_id, transaction_type, amount,
                balance_before, balance_after, status, channel, description
            ) VALUES (
                v_ref, v_acc_id, 'INTEREST_CREDIT', v_interest,
                v_balance, (v_balance + v_interest), 'COMPLETED', 'SYSTEM',
                CONCAT('Monthly Interest Accrual @ ', v_rate, '% p.a.')
            );

            SET p_processed_count = p_processed_count + 1;
            SET p_total_interest = p_total_interest + v_interest;
        END IF;
    END LOOP;

    CLOSE cur_savings;
END //

DELIMITER ;

