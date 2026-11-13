-- ============================================================================
-- NovaBank - Database Schema (01_schema.sql)
-- DBMS Banking Management System Project
-- Engine: MySQL 8.x+ (InnoDB), Character Set: utf8mb4
-- ============================================================================

CREATE DATABASE IF NOT EXISTS novabank
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE novabank;

-- Disable foreign key checks during schema creation
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------------------------------------------------------
-- Table: branches
-- Represents physical and digital branches of NovaBank (3NF)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS branches;
CREATE TABLE branches (
    branch_id INT AUTO_INCREMENT PRIMARY KEY,
    branch_code VARCHAR(10) NOT NULL UNIQUE,
    branch_name VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_branch_city (city)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table: customers
-- Central customer entity normalized according to 3NF / BCNF
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_number VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL UNIQUE,
    national_id VARCHAR(50) NOT NULL UNIQUE,
    date_of_birth DATE NOT NULL,
    address_line1 VARCHAR(150) NOT NULL,
    address_line2 VARCHAR(150),
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    kyc_status ENUM('PENDING', 'VERIFIED', 'REJECTED') DEFAULT 'VERIFIED',
    customer_tier ENUM('STANDARD', 'PREMIUM', 'VIP') DEFAULT 'STANDARD',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_customer_email (email),
    INDEX idx_customer_phone (phone),
    INDEX idx_customer_names (last_name, first_name)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table: users
-- Portal authentication accounts with role-based access control (RBAC)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS users;
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('ADMIN', 'TELLER', 'AUDITOR', 'CUSTOMER') NOT NULL DEFAULT 'CUSTOMER',
    customer_id INT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE SET NULL,
    INDEX idx_user_role (role)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table: accounts
-- Core account entity with check constraints on balance & status
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS accounts;
CREATE TABLE accounts (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    account_number VARCHAR(20) NOT NULL UNIQUE,
    customer_id INT NOT NULL,
    branch_id INT NOT NULL,
    account_type ENUM('SAVINGS', 'CHECKING', 'BUSINESS', 'FIXED_DEPOSIT') NOT NULL,
    balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    minimum_balance DECIMAL(15, 2) NOT NULL DEFAULT 1000.00,
    interest_rate DECIMAL(5, 2) NOT NULL DEFAULT 4.00,
    currency VARCHAR(3) DEFAULT 'INR',
    status ENUM('ACTIVE', 'FROZEN', 'DORMANT', 'CLOSED') NOT NULL DEFAULT 'ACTIVE',
    opened_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_account_balance CHECK (balance >= 0.00),
    CONSTRAINT chk_min_balance CHECK (minimum_balance >= 0.00),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE RESTRICT,
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id) ON DELETE RESTRICT,
    INDEX idx_account_customer (customer_id),
    INDEX idx_account_status (status),
    INDEX idx_account_type (account_type)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table: beneficiaries
-- Saved payees for customer account transfers
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS beneficiaries;
CREATE TABLE beneficiaries (
    beneficiary_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    beneficiary_name VARCHAR(100) NOT NULL,
    account_number VARCHAR(20) NOT NULL,
    bank_name VARCHAR(100) DEFAULT 'NovaBank',
    routing_code VARCHAR(20) DEFAULT 'NVB0001',
    nickname VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    UNIQUE KEY uq_cust_beneficiary (customer_id, account_number)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table: transactions
-- Immutable ledger recording all financial and balance adjustments
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS transactions;
CREATE TABLE transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    reference_no VARCHAR(40) NOT NULL UNIQUE,
    account_id INT NOT NULL,
    transaction_type ENUM('DEPOSIT', 'WITHDRAWAL', 'TRANSFER_IN', 'TRANSFER_OUT', 'LOAN_DISBURSEMENT', 'LOAN_REPAYMENT', 'INTEREST_CREDIT') NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    balance_before DECIMAL(15, 2) NOT NULL,
    balance_after DECIMAL(15, 2) NOT NULL,
    related_account_id INT NULL,
    status ENUM('PENDING', 'COMPLETED', 'FAILED', 'REVERSED') NOT NULL DEFAULT 'COMPLETED',
    channel ENUM('ONLINE', 'ATM', 'BRANCH', 'SYSTEM') NOT NULL DEFAULT 'ONLINE',
    description VARCHAR(255),
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_txn_amount CHECK (amount > 0.00),
    FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE RESTRICT,
    FOREIGN KEY (related_account_id) REFERENCES accounts(account_id) ON DELETE SET NULL,
    INDEX idx_txn_account_date (account_id, transaction_date),
    INDEX idx_txn_type_date (transaction_type, transaction_date),
    INDEX idx_txn_reference (reference_no)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table: loans
-- Loan facilities linked to accounts with EMI amortization
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS loans;
CREATE TABLE loans (
    loan_id INT AUTO_INCREMENT PRIMARY KEY,
    loan_number VARCHAR(20) NOT NULL UNIQUE,
    customer_id INT NOT NULL,
    account_id INT NOT NULL,
    loan_type ENUM('HOME', 'AUTO', 'PERSONAL', 'EDUCATION', 'BUSINESS') NOT NULL,
    principal_amount DECIMAL(15, 2) NOT NULL,
    interest_rate DECIMAL(5, 2) NOT NULL,
    term_months INT NOT NULL,
    monthly_emi DECIMAL(15, 2) NOT NULL,
    outstanding_balance DECIMAL(15, 2) NOT NULL,
    status ENUM('APPLIED', 'APPROVED', 'DISBURSED', 'ACTIVE', 'PAID_OFF', 'DEFAULTED') DEFAULT 'ACTIVE',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_loan_principal CHECK (principal_amount > 0.00),
    CONSTRAINT chk_loan_term CHECK (term_months > 0),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE RESTRICT,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE RESTRICT,
    INDEX idx_loan_customer (customer_id),
    INDEX idx_loan_status (status)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table: loan_payments
-- Payment ledger for amortized loan EMIs
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS loan_payments;
CREATE TABLE loan_payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    loan_id INT NOT NULL,
    payment_number INT NOT NULL,
    payment_amount DECIMAL(15, 2) NOT NULL,
    principal_component DECIMAL(15, 2) NOT NULL,
    interest_component DECIMAL(15, 2) NOT NULL,
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('COMPLETED', 'PENDING', 'FAILED') DEFAULT 'COMPLETED',
    FOREIGN KEY (loan_id) REFERENCES loans(loan_id) ON DELETE RESTRICT,
    INDEX idx_loan_pay_loan (loan_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table: cards
-- Payment cards (Debit/Credit) linked to bank accounts
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS cards;
CREATE TABLE cards (
    card_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    card_number_masked VARCHAR(20) NOT NULL,
    card_type ENUM('DEBIT', 'CREDIT') NOT NULL,
    card_brand ENUM('VISA', 'MASTERCARD') DEFAULT 'VISA',
    expiry_date VARCHAR(5) NOT NULL,
    daily_limit DECIMAL(10, 2) DEFAULT 2500.00,
    status ENUM('ACTIVE', 'BLOCKED', 'EXPIRED') DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE CASCADE,
    INDEX idx_card_account (account_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table: audit_logs
-- Central audit trail automatically populated via triggers for all critical changes
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS audit_logs;
CREATE TABLE audit_logs (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    record_id INT NOT NULL,
    old_values JSON NULL,
    new_values JSON NULL,
    changed_by VARCHAR(100) DEFAULT 'system',
    action_summary VARCHAR(255),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_table_rec (table_name, record_id),
    INDEX idx_audit_timestamp (timestamp)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table: query_demo_data
-- Synthetic dataset for the DBMS Lab Query Optimization & Indexing demonstrations
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS query_demo_data;
CREATE TABLE query_demo_data (
    record_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_code VARCHAR(30) NOT NULL,
    city VARCHAR(50) NOT NULL,
    txn_category VARCHAR(30) NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    created_date DATE NOT NULL,
    notes TEXT,
    indexed_tag VARCHAR(50) NOT NULL,
    unindexed_tag VARCHAR(50) NOT NULL,
    INDEX idx_demo_indexed_tag (indexed_tag),
    INDEX idx_demo_city_amt (city, amount)
) ENGINE=InnoDB;

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

