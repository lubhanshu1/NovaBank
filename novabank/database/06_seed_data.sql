-- ============================================================================
-- NovaBank - Comprehensive Seed Data (06_seed_data.sql)
-- DBMS Banking Management System Project (INR Currency & Indian Metros)
-- Realistic test data across all tables: branches, accounts, transactions,
-- loans, cards, and query optimization synthetic records.
-- ============================================================================

USE novabank;

-- ----------------------------------------------------------------------------
-- 1. Branches (Indian Metro Banking Hubs)
-- ----------------------------------------------------------------------------
INSERT INTO branches (branch_id, branch_code, branch_name, address, city, state, postal_code, phone) VALUES
(1, 'NVB-MUM01', 'Mumbai Fort Flagship Branch', 'Nariman Point, Marine Drive', 'Mumbai', 'Maharashtra', '400021', '+91 (22) 2288-0101'),
(2, 'NVB-BLR02', 'Bengaluru Tech Corridor Hub', '80 Feet Road, Koramangala 4th Block', 'Bengaluru', 'Karnataka', '560034', '+91 (80) 4112-0102'),
(3, 'NVB-DEL03', 'Delhi Connaught Place Branch', 'Barakhamba Road, Connaught Place', 'New Delhi', 'Delhi', '110001', '+91 (11) 2334-0103'),
(4, 'NVB-HYD04', 'Hyderabad Cyberabad Hub', 'Hitec City, Madhapur', 'Hyderabad', 'Telangana', '500081', '+91 (40) 6678-0104'),
(5, 'NVB-CHE05', 'Chennai Marina Gateway', 'Anna Salai, Thousand Lights', 'Chennai', 'Tamil Nadu', '600006', '+91 (44) 2855-0105')
ON DUPLICATE KEY UPDATE branch_name=VALUES(branch_name);

-- ----------------------------------------------------------------------------
-- 2. Customers (Indian Citizens & KYC Profiles)
-- ----------------------------------------------------------------------------
INSERT INTO customers (customer_id, customer_number, first_name, last_name, email, phone, national_id, date_of_birth, address_line1, address_line2, city, state, postal_code, kyc_status, customer_tier) VALUES
(1,  'CUST-10001', 'Kush',   'Dalal',    'kush@novabank.in',       '+91 98201 12345', 'PAN-ABCDE1234F', '2002-05-14', '74 Marine Drive', 'Apt 4B', 'Mumbai', 'Maharashtra', '400020', 'VERIFIED', 'VIP'),
(2,  'CUST-10002', 'Priya',  'Sharma',   'priya.sharma@example.in','+91 98450 23456', 'PAN-BCDEF2345G', '1995-09-22', '120 Koramangala Ring Road', NULL, 'Bengaluru', 'Karnataka', '560034', 'VERIFIED', 'PREMIUM'),
(3,  'CUST-10003', 'Rahul',  'Verma',    'rahul.verma@example.in', '+91 98110 34567', 'PAN-CDEFG3456H', '1988-12-03', '88 Barakhamba Lane', 'Suite 14', 'New Delhi', 'Delhi', '110001', 'VERIFIED', 'PREMIUM'),
(4,  'CUST-10004', 'Ananya', 'Iyer',     'ananya.iyer@example.in', '+91 94440 45678', 'PAN-DEFGH4567J', '1992-04-18', '204 Anna Salai', NULL, 'Chennai', 'Tamil Nadu', '600006', 'VERIFIED', 'STANDARD'),
(5,  'CUST-10005', 'Vikram', 'Malhotra', 'vikram.m@example.in',    '+91 98300 56789', 'PAN-EFGHI5678K', '1984-11-30', '1400 Jubilee Hills', 'Road No 36', 'Hyderabad', 'Telangana', '500033', 'VERIFIED', 'VIP'),
(6,  'CUST-10006', 'Sneha',  'Reddy',    'sneha.reddy@example.in', '+91 98660 67890', 'PAN-FGHIJ6789L', '1990-07-09', '45 Gachibowli Main Rd', 'Tower 3', 'Hyderabad', 'Telangana', '500032', 'VERIFIED', 'STANDARD'),
(7,  'CUST-10007', 'Arjun',  'Mehta',    'arjun.mehta@example.in', '+91 97120 78901', 'PAN-GHIJK7890M', '1998-01-25', '312 CG Road', NULL, 'Ahmedabad', 'Gujarat', '380009', 'VERIFIED', 'STANDARD'),
(8,  'CUST-10008', 'Neha',   'Gupta',    'neha.gupta@example.in',  '+91 99270 89012', 'PAN-HIJKL8901N', '1993-08-11', '600 Civil Lines', 'Unit 502', 'Jaipur', 'Rajasthan', '302006', 'PENDING', 'STANDARD'),
(9,  'CUST-10009', 'Rohan',  'Deshmukh', 'rohan.d@example.in',     '+91 98220 90123', 'PAN-IJKLM9012P', '1980-03-15', '701 FC Road, Deccan', NULL, 'Pune', 'Maharashtra', '411004', 'VERIFIED', 'PREMIUM'),
(10, 'CUST-10010', 'Pooja',  'Nair',     'pooja.nair@example.in',  '+91 98470 01234', 'PAN-JKLMN0123Q', '1997-10-04', '300 MG Road', 'Suite 800', 'Bengaluru', 'Karnataka', '560001', 'VERIFIED', 'STANDARD')
ON DUPLICATE KEY UPDATE first_name=VALUES(first_name);

-- ----------------------------------------------------------------------------
-- 3. Users (Portal Authentication)
-- Passwords:
--   admin    -> admin123
--   teller1  -> teller123
--   auditor1 -> audit123
--   kush     -> kush123
--   priya    -> priya123
-- ----------------------------------------------------------------------------
INSERT INTO users (user_id, username, password_hash, role, customer_id, is_active) VALUES
(1, 'admin',    'scrypt:32768:8:1$F4yqzhHkdRtwZqBB$144cf3d3c160fcb2604797190a2dfae218846eca469b414be14b8b04d3560a9594c7b217a51d1f4703fd27b941944c53d972e4e047e89c4a84bdba141a7a0928', 'ADMIN', NULL, TRUE),
(2, 'teller1',  'scrypt:32768:8:1$7sIHFUQdrkPnqIdp$0417786408425c730f49ea8b57b767b5fcd758ae1123e5a382c2121f92594c5267a8264915113625a32aef0ceda75a42cf842fa8f0114f5956a6a29d282f623b', 'TELLER', NULL, TRUE),
(3, 'auditor1', 'scrypt:32768:8:1$QkqedZDle6IN1lBd$1fd18d0f8997c80c92802cfb9676c8c6e17ac45ee33c08e0df9229dcda79f589a07e769f6a352fb332a1749348a7825ac0a7602e4bfae8160755dd82caca954c', 'AUDITOR', NULL, TRUE),
(4, 'kush',     'scrypt:32768:8:1$sPHUAGwn9RnqwYRd$e639a591d80b4e48083cf1c76c439e5ac457fe830e05dde09b3f45b8654e61187473b82c8191a8df3c2c900d3fc6484a0b46392a0d62e269859900e3994889c5', 'CUSTOMER', 1, TRUE),
(5, 'priya',    'scrypt:32768:8:1$hmbhL8LVeEJFyJWT$2983807193e94062a6e49549707ac1a81f4fece30d524774b53485d7c8257e928305bea80be526f985a901f60b5d94f845713f6eec21a0ca49b9ada676c28743', 'CUSTOMER', 2, TRUE)
ON DUPLICATE KEY UPDATE password_hash=VALUES(password_hash);

-- ----------------------------------------------------------------------------
-- 4. Accounts (INR Balances & Minimum Thresholds)
-- ----------------------------------------------------------------------------
INSERT INTO accounts (account_id, account_number, customer_id, branch_id, account_type, balance, minimum_balance, interest_rate, currency, status, opened_date) VALUES
(1,  '1001001001', 1,  1, 'CHECKING',       354000.50, 1000.00, 3.50, 'INR', 'ACTIVE', '2023-01-15'),
(2,  '1001001002', 1,  1, 'SAVINGS',        887500.00, 2000.00, 4.50, 'INR', 'ACTIVE', '2023-03-20'),
(3,  '1001002001', 2,  2, 'CHECKING',       124000.00, 1000.00, 3.50, 'INR', 'ACTIVE', '2023-02-10'),
(4,  '1001002002', 2,  2, 'SAVINGS',        451000.25, 2000.00, 4.50, 'INR', 'ACTIVE', '2023-04-12'),
(5,  '1001003001', 3,  3, 'BUSINESS',      1482000.75, 5000.00, 3.00, 'INR', 'ACTIVE', '2022-11-05'),
(6,  '1001003002', 3,  3, 'SAVINGS',        310000.00, 2000.00, 4.25, 'INR', 'ACTIVE', '2023-01-08'),
(7,  '1001004001', 4,  4, 'CHECKING',        68500.50, 1000.00, 3.50, 'INR', 'ACTIVE', '2023-06-18'),
(8,  '1001005001', 5,  5, 'CHECKING',       723000.00, 2000.00, 3.50, 'INR', 'ACTIVE', '2022-09-14'),
(9,  '1001005002', 5,  5, 'FIXED_DEPOSIT', 2500000.00, 10000.00, 7.25, 'INR', 'ACTIVE', '2023-05-01'),
(10, '1001006001', 6,  1, 'SAVINGS',         94000.00, 1000.00, 4.00, 'INR', 'ACTIVE', '2023-07-22'),
(11, '1001007001', 7,  2, 'CHECKING',        41200.00, 1000.00, 3.50, 'INR', 'ACTIVE', '2023-08-05'),
(12, '1001008001', 8,  3, 'SAVINGS',         15000.00, 1000.00, 4.00, 'INR', 'FROZEN', '2023-09-12'),
(13, '1001009001', 9,  4, 'BUSINESS',       980000.00, 5000.00, 3.00, 'INR', 'ACTIVE', '2023-03-30'),
(14, '1001010001', 10, 5, 'CHECKING',        82500.25, 1000.00, 3.50, 'INR', 'ACTIVE', '2023-10-10')
ON DUPLICATE KEY UPDATE balance=VALUES(balance);

-- ----------------------------------------------------------------------------
-- 5. Beneficiaries
-- ----------------------------------------------------------------------------
INSERT INTO beneficiaries (beneficiary_id, customer_id, beneficiary_name, account_number, bank_name, routing_code, nickname) VALUES
(1, 1, 'Priya Sharma',   '1001002001', 'NovaBank Bengaluru Hub', 'NVB0002', 'Priya Checking'),
(2, 1, 'Rahul Verma',    '1001003001', 'NovaBank Delhi Branch',   'NVB0003', 'Rahul Business'),
(3, 2, 'Kush Dalal',     '1001001001', 'NovaBank Mumbai Fort',    'NVB0001', 'Kush Primary'),
(4, 2, 'Vikram Malhotra','1001005001', 'NovaBank Hyderabad Hub', 'NVB0005', 'Vikram Malhotra'),
(5, 3, 'Ananya Iyer',    '1001004001', 'NovaBank Chennai Hub',   'NVB0004', 'Ananya Personal')
ON DUPLICATE KEY UPDATE beneficiary_name=VALUES(beneficiary_name);

-- ----------------------------------------------------------------------------
-- 6. Historical Transactions (in INR)
-- ----------------------------------------------------------------------------
INSERT INTO transactions (transaction_id, reference_no, account_id, transaction_type, amount, balance_before, balance_after, related_account_id, status, channel, description, transaction_date) VALUES
(1,  'TXN-INIT-001',        1, 'DEPOSIT',         250000.00,      0.00, 250000.00, NULL, 'COMPLETED', 'BRANCH', 'Initial deposit at opening',           '2023-01-15 10:30:00'),
(2,  'TXN-INIT-002',        2, 'DEPOSIT',         750000.00,      0.00, 750000.00, NULL, 'COMPLETED', 'BRANCH', 'Special savings opening balance',       '2023-03-20 11:15:00'),
(3,  'TXN-INIT-003',        3, 'DEPOSIT',         150000.00,      0.00, 150000.00, NULL, 'COMPLETED', 'BRANCH', 'Account opening cash deposit',          '2023-02-10 09:45:00'),
(4,  'TXN-TRF-202304-001',  1, 'TRANSFER_OUT',     25000.00, 250000.00, 225000.00,    3, 'COMPLETED', 'ONLINE', 'Project consulting fee transfer to Priya', '2023-04-05 14:20:00'),
(5,  'TXN-RCV-202304-001',  3, 'TRANSFER_IN',      25000.00, 150000.00, 175000.00,    1, 'COMPLETED', 'ONLINE', 'Consulting fee received from Kush',        '2023-04-05 14:20:00'),
(6,  'TXN-DEP-202305-002',  1, 'DEPOSIT',         150000.00, 225000.00, 375000.00, NULL, 'COMPLETED', 'ONLINE', 'Client invoice NEFT settlement',       '2023-05-02 09:00:00'),
(7,  'TXN-WTH-202305-003',  1, 'WITHDRAWAL',        8000.00, 375000.00, 367000.00, NULL, 'COMPLETED', 'ATM',    'ATM cash withdrawal Nariman Point',    '2023-05-18 16:45:00'),
(8,  'TXN-INT-202305-004',  2, 'INTEREST_CREDIT',   2650.50, 750000.00, 752650.50, NULL, 'COMPLETED', 'SYSTEM', 'Monthly savings interest accrual',      '2023-05-31 23:59:59'),
(9,  'TXN-TRF-202306-005',  3, 'TRANSFER_OUT',     51000.00, 175000.00, 124000.00,    4, 'COMPLETED', 'ONLINE', 'Monthly automated investment allocation','2023-06-01 10:00:00'),
(10, 'TXN-RCV-202306-005',  4, 'TRANSFER_IN',      51000.00, 400000.25, 451000.25,    3, 'COMPLETED', 'ONLINE', 'Monthly transfer from checking',            '2023-06-01 10:00:00'),
(11, 'TXN-DEP-202307-006',  5, 'DEPOSIT',         500000.00, 982000.75, 1482000.75,NULL, 'COMPLETED', 'ONLINE', 'Vendor commercial settlement RTGS',     '2023-07-14 12:30:00'),
(12, 'TXN-TRF-202308-007',  1, 'TRANSFER_OUT',     12790.00, 367000.00, 354210.00,    3, 'COMPLETED', 'ONLINE', 'Co-working office space share',         '2023-08-20 15:10:00'),
(13, 'TXN-RCV-202308-007',  3, 'TRANSFER_IN',      12790.00, 124000.00, 136790.00,    1, 'COMPLETED', 'ONLINE', 'Office space share received from Kush',   '2023-08-20 15:10:00'),
(14, 'TXN-INT-202308-008',  2, 'INTEREST_CREDIT',   3145.00, 884355.00, 887500.00, NULL, 'COMPLETED', 'SYSTEM', 'Quarterly interest credit',             '2023-08-31 23:59:59'),
(15, 'TXN-TRF-202309-009',  8, 'DEPOSIT',         250000.00, 473000.00, 723000.00, NULL, 'COMPLETED', 'BRANCH', 'Inter-bank IMPS transfer deposit',       '2023-09-10 11:00:00'),
(16, 'TXN-WTH-202310-010',  4, 'WITHDRAWAL',       12000.00, 463000.25, 451000.25, NULL, 'COMPLETED', 'ATM',    'Weekend ATM withdrawal Koramangala',   '2023-10-02 18:20:00')
ON DUPLICATE KEY UPDATE amount=VALUES(amount);

-- ----------------------------------------------------------------------------
-- 7. Loans and Amortization Payments (in INR)
-- ----------------------------------------------------------------------------
INSERT INTO loans (loan_id, loan_number, customer_id, account_id, loan_type, principal_amount, interest_rate, term_months, monthly_emi, outstanding_balance, status, start_date, end_date) VALUES
(1, 'LN-2301-44012', 1, 1, 'HOME',      4500000.00, 8.50, 240, 39052.12, 4325000.00, 'ACTIVE', '2023-01-20', '2043-01-20'),
(2, 'LN-2303-88192', 2, 3, 'AUTO',       850000.00, 9.25,  60,  17743.80,  721000.00, 'ACTIVE', '2023-03-15', '2028-03-15'),
(3, 'LN-2305-19284', 3, 5, 'BUSINESS',  2500000.00, 11.50, 84,  43512.40, 2280000.00, 'ACTIVE', '2023-05-10', '2030-05-10'),
(4, 'LN-2307-55120', 5, 8, 'PERSONAL',   500000.00, 12.50, 36,  16726.80,  395000.00, 'ACTIVE', '2023-07-01', '2026-07-01')
ON DUPLICATE KEY UPDATE outstanding_balance=VALUES(outstanding_balance);

INSERT INTO loan_payments (payment_id, loan_id, payment_number, payment_amount, principal_component, interest_component, payment_date, status) VALUES
(1, 1, 1, 39052.12,  7177.12, 31875.00, '2023-02-20 08:00:00', 'COMPLETED'),
(2, 1, 2, 39052.12,  7227.96, 31824.16, '2023-03-20 08:00:00', 'COMPLETED'),
(3, 2, 1, 17743.80, 11191.72,  6552.08, '2023-04-15 08:00:00', 'COMPLETED'),
(4, 2, 2, 17743.80, 11278.07,  6465.73, '2023-05-15 08:00:00', 'COMPLETED'),
(5, 3, 1, 43512.40, 19554.07, 23958.33, '2023-06-10 08:00:00', 'COMPLETED')
ON DUPLICATE KEY UPDATE payment_amount=VALUES(payment_amount);

-- ----------------------------------------------------------------------------
-- 8. Payment Cards
-- ----------------------------------------------------------------------------
INSERT INTO cards (card_id, account_id, card_number_masked, card_type, card_brand, expiry_date, daily_limit, status) VALUES
(1, 1, '4532 **** **** 8821', 'DEBIT',  'VISA',       '05/28', 50000.00,  'ACTIVE'),
(2, 1, '5412 **** **** 9012', 'CREDIT', 'MASTERCARD', '09/27', 150000.00, 'ACTIVE'),
(3, 3, '4024 **** **** 3391', 'DEBIT',  'VISA',       '11/27', 50000.00,  'ACTIVE'),
(4, 5, '5241 **** **** 6718', 'DEBIT',  'MASTERCARD', '04/29', 200000.00, 'ACTIVE'),
(5, 8, '4111 **** **** 1194', 'DEBIT',  'VISA',       '12/28', 100000.00, 'ACTIVE')
ON DUPLICATE KEY UPDATE status=VALUES(status);

-- ----------------------------------------------------------------------------
-- 9. Initial Audit Logs
-- ----------------------------------------------------------------------------
INSERT INTO audit_logs (audit_id, table_name, operation, record_id, action_summary, changed_by, old_values, new_values, timestamp) VALUES
(1, 'customers',    'INSERT', 1, 'Customer Kush Dalal onboarded (VIP Tier)', 'system', NULL, '{"customer_number": "CUST-10001", "name": "Kush Dalal"}', '2023-01-15 10:00:00'),
(2, 'accounts',     'INSERT', 1, 'Checking Account 1001001001 opened with initial deposit ₹250000.00', 'system', NULL, '{"account_number": "1001001001", "balance": 250000.00}', '2023-01-15 10:30:00'),
(3, 'transactions', 'INSERT', 1, 'Initial deposit TXN-INIT-001 (₹250,000.00) completed', 'system', NULL, '{"type": "DEPOSIT", "amount": 250000.00}', '2023-01-15 10:30:00'),
(4, 'accounts',     'UPDATE', 1, 'Account 1001001001 | Bal: ₹250000.00 -> ₹225000.00 (Diff: -25000.00)', 'novabank_app', '{"balance": 250000.00}', '{"balance": 225000.00}', '2023-04-05 14:20:00'),
(5, 'loans',        'INSERT', 1, 'Home Mortgage LN-2301-44012 approved for ₹4,500,000.00', 'system', NULL, '{"loan_number": "LN-2301-44012", "principal": 4500000.00}', '2023-01-20 11:00:00')
ON DUPLICATE KEY UPDATE action_summary=VALUES(action_summary);

-- ----------------------------------------------------------------------------
-- Query demo records are generated by setup_tidb.py for TiDB compatibility.
