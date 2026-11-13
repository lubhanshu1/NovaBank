> **TiDB Cloud deployment note:** For the free-tier Vercel/TiDB deployment, follow [README_TIDB_VERCEL.md](README_TIDB_VERCEL.md). TiDB does not support MySQL stored procedures or triggers; NovaBank's financial operations and audit writes have been moved into transactional Python services in `backend/db.py`. The original SQL procedure/trigger files are retained for the MySQL/DBMS coursework reference and must not be executed on TiDB.

# 🏦 NovaBank - Core Banking Management System & DBMS Academic Lab

> **B.E. CSE (AI&ML) Course Project in Database Management Systems (DBMS)**  
> Built with **MySQL 8.x (InnoDB)**, **Python / Flask REST API**, and a modern **Vanilla Web Dashboard**.

---

## 🌟 Overview

**NovaBank** is an enterprise-grade Banking Management System engineered to prove real DBMS mastery. Rather than burying financial business rules in application code, **business logic lives directly in the database engine**:

- ⚡ **Atomic Stored Procedures** with row-level locks (`SELECT ... FOR UPDATE`) and structured error handlers (`DECLARE EXIT HANDLER FOR SQLEXCEPTION`).
- 🛡️ **Autonomous Database Triggers** enforcing balance thresholds and logging immutable JSON audit trails.
- 📊 **Analytical Views** powering executive dashboards, compliance alerts, and branch rankings.
- 🔬 **The DBMS Academic Lab**: A live, interactive laboratory inside the app that live-demonstrates:
  1. **Query Optimizer & EXPLAIN Visualizer**: Full Table Scans (ALL) vs B-Tree Index Seeks (`ref`/`range`).
  2. **ACID Atomicity & Crash Recovery**: Two-step transfers with simulated power disruption and automatic rollback.
  3. **ACID Consistency & Integrity**: Live testing of `CHECK` constraints, `UNIQUE` candidate keys, and `FOREIGN KEY ... ON DELETE RESTRICT`.
  4. **ACID Isolation & MVCC**: Matrix of `READ UNCOMMITTED`, `READ COMMITTED`, `REPEATABLE READ`, and `SERIALIZABLE`.
  5. **Concurrency & Deadlock Detection**: Contending reverse-order transactions triggering InnoDB `ERROR 1213`.
  6. **Stored Procedures & Cursors**: Batch monthly interest accrual using `CURSOR` loops.
  7. **Relational Schema Normalization**: Step-by-step breakdown of 1NF, 2NF, 3NF, and BCNF.

---

## 🛠️ Tech Stack

- **Operating Systems**: Windows 10/11 & macOS / Linux
- **Database Engine**: MySQL 8.x / 9.x (InnoDB Storage Engine, `utf8mb4` character set)
- **Backend API**: Python 3.10+ with Flask, `mysql-connector-python`, `python-dotenv`, `Flask-CORS`, `werkzeug`
- **Frontend UI**: Vanilla HTML5, CSS3, Vanilla JavaScript (zero node/npm build dependencies), Chart.js (CDN), Inter Google Font

---

## 🚀 Quick Start Guide

### On macOS / Linux

1. Ensure MySQL is running locally:
   ```bash
   brew services start mysql
   ```
2. Run the automated setup script (creates virtual environment, installs packages, rebuilds and seeds MySQL):
   ```bash
   ./setup.sh
   ```
3. Start the application:
   ```bash
   ./run.sh
   ```
   *The script checks database connectivity, displays status logs in the terminal, and launches your browser at `http://127.0.0.1:5000`.*

---

### On Windows 10 / 11

1. Ensure MySQL Server service is running.
2. Double-click `setup.bat` (or run in Command Prompt / PowerShell):
   ```cmd
   setup.bat
   ```
   *Creates `venv`, installs `requirements.txt`, creates `.env`, rebuilds `novabank` schema and seeds data, then runs tests.*
3. Launch NovaBank:
   ```cmd
   run.bat
   ```
   *Checks MySQL connection, outputs terminal logs, and opens `http://127.0.0.1:5000`.*

---

## 🔑 Pre-Seeded Personas & Demo Accounts

Use the **Persona Switcher** in the top navigation bar to test different database roles live:

| Persona Username | Password | Role | Description |
| :--- | :--- | :--- | :--- |
| `admin` | `admin123` | **ADMIN** | Full administrative and schema management access. |
| `teller1` | `teller123` | **TELLER** | Branch teller: executes deposits, withdrawals, transfers. |
| `auditor1` | `audit123` | **AUDITOR** | Read-only compliance inspector: views and audit logs. |
| `kush` | `kush123` | **CUSTOMER** | VIP Banking Customer (Kush Dalal) - Acct: `1001001001`. |
| `priya` | `priya123` | **CUSTOMER** | Verified Customer (Priya Sharma) - Acct: `1001002001`. |

---

## 📚 Comprehensive Documentation & Lab Manuals

- 🏛️ **[DATABASE.md](DATABASE.md)**: Full relational data dictionary (all 11 tables), field constraints, and step-by-step transaction lifecycles (`sp_transfer_funds`, deadlock prevention, locks, triggers, rollback/commit).
- 🔬 **[DBMS_LAB.md](DBMS_LAB.md)**: Complete academic syllabus lab manual detailing Query Optimization, `EXPLAIN FORMAT=JSON`, ACID properties, concurrency control, cursors, and BCNF normalization.

---

## 📁 Project Directory Structure

```text
novabank/
├── .env.example                  # Environment configuration template
├── .env                          # Local database connection settings
├── requirements.txt              # Python dependencies
├── setup.sh / setup.bat          # 1-Click environment & database setup
├── run.sh / run.bat              # App launcher with terminal connection logs
├── reset_db.sh / reset_db.bat    # 1-Click database drop and re-seed
├── backup.sh / backup.bat        # mysqldump database backup utility
├── restore.sh / restore.bat      # Database restore utility
│
├── database/                     # Versioned MySQL Scripts (Database-First Design)
│   ├── 01_schema.sql             # 11 Tables, PKs, FKs, CHECK constraints, Indexes
│   ├── 02_views.sql              # 6 Analytical & Reporting Views
│   ├── 03_procedures.sql         # 7 Stored Procedures with ACID Transactions & Cursors
│   ├── 04_triggers.sql           # 6 Triggers for Audit Trails & Integrity
│   ├── 05_roles_and_security.sql # MySQL 8.x RBAC (admin, teller, auditor) & app user
│   ├── 06_seed_data.sql          # 14 Accounts, 2500 Query Demo records, loans, cards
│   ├── reset_db.py               # Cross-platform Python database rebuilder
│   ├── backup.py                 # Cross-platform backup script
│   └── restore.py                # Cross-platform restore script
│
├── backend/                      # Thin Flask REST API
│   ├── app.py                    # App factory, static frontend server, health logs
│   ├── config.py                 # Configuration loader from .env
│   ├── db.py                     # Connection pool, parameterized queries, call_procedure
│   ├── test_backend.py           # Comprehensive automated unittest suite
│   └── routes/
│       ├── auth.py               # User login, session, and persona switching
│       ├── accounts.py           # Accounts ledger & sp_open_account caller
│       ├── transactions.py       # Transfers (sp_transfer_funds), deposits, withdrawals
│       ├── loans.py              # Loan origination (sp_apply_loan) & EMI payments
│       ├── analytics.py          # View readers (vw_customer_account_summary, etc.)
│       ├── audit.py              # Audit log inspector
│       └── dbms_lab.py           # Live DBMS Syllabus Lab endpoints
│
└── frontend/                     # Modern Web UI (No build step required)
    ├── index.html                # App shell, sidebar, and 6 functional tabs
    ├── css/
    │   └── styles.css            # Fintech dark-mode stylesheet
    └── js/
        ├── api.js                # Fetch API client & toast notifications
        ├── app.js                # Main event listeners, navigation & modals
        ├── dashboard.js          # Chart.js visualizations & KPI metrics
        ├── accounts.js           # Accounts ledger & modal handlers
        ├── transactions.js       # Fund transfer & cash transaction handlers
        ├── loans.js              # Loan portfolio & EMI payment handlers
        └── lab.js                # Interactive DBMS Syllabus Laboratory controller
```

---

## 🎓 DBMS Course Concepts Mapped to Code

| Syllabus Concept | NovaBank Implementation | Code Location |
| :--- | :--- | :--- |
| **Relational Normalization** | 1NF, 2NF, 3NF, and BCNF schema. Branch data split to eliminate transitive dependencies. | [`01_schema.sql`](file:///Users/kushdalal/main/novabank/database/01_schema.sql) |
| **Stored Procedures** | Atomic fund transfers, loan origination with mathematical EMI amortization. | [`03_procedures.sql`](file:///Users/kushdalal/main/novabank/database/03_procedures.sql) |
| **Cursors** | `sp_monthly_interest_accrual` iterates across savings accounts in an atomic batch. | [`03_procedures.sql`](file:///Users/kushdalal/main/novabank/database/03_procedures.sql#L330-L380) |
| **Triggers** | `trg_accounts_before_update` enforces minimum balance; `trg_accounts_after_update` logs JSON audit diffs. | [`04_triggers.sql`](file:///Users/kushdalal/main/novabank/database/04_triggers.sql) |
| **Views** | Reporting views (`vw_customer_account_summary`, `vw_daily_transaction_metrics`, `vw_high_risk_transactions`). | [`02_views.sql`](file:///Users/kushdalal/main/novabank/database/02_views.sql) |
| **Query Optimization** | `EXPLAIN FORMAT=JSON` visualizer, cost estimation, Table Scan (ALL) vs B-Tree Index Seek. | [`dbms_lab.py`](file:///Users/kushdalal/main/novabank/backend/routes/dbms_lab.py#L18-L110) |
| **ACID: Atomicity** | Two-step transfer with failure simulation and automatic rollback. | [`dbms_lab.py`](file:///Users/kushdalal/main/novabank/backend/routes/dbms_lab.py#L115-L210) |
| **ACID: Consistency** | Database engine enforcement of domain `CHECK`, `UNIQUE`, and `FOREIGN KEY RESTRICT`. | [`dbms_lab.py`](file:///Users/kushdalal/main/novabank/backend/routes/dbms_lab.py#L225-L290) |
| **ACID: Isolation** | Comparison of `READ UNCOMMITTED`, `READ COMMITTED`, `REPEATABLE READ`, and `SERIALIZABLE`. | [`dbms_lab.py`](file:///Users/kushdalal/main/novabank/backend/routes/dbms_lab.py#L300-L360) |
| **Concurrency Control** | Contending threads simulating deadlocks via `SELECT ... FOR UPDATE`; ordered lock resolution. | [`dbms_lab.py`](file:///Users/kushdalal/main/novabank/backend/routes/dbms_lab.py#L370-L425) |
| **Role-Based Access (RBAC)** | MySQL 8.x roles (`novabank_admin_role`, `novabank_teller_role`, `novabank_auditor_role`). | [`05_roles_and_security.sql`](file:///Users/kushdalal/main/novabank/database/05_roles_and_security.sql) |
| **Database Recovery** | Hot backups via `mysqldump` with `--single-transaction` and point-in-time restore. | [`backup.py`](file:///Users/kushdalal/main/novabank/database/backup.py) & [`restore.py`](file:///Users/kushdalal/main/novabank/database/restore.py) |

---

## 🧪 Running Automated Tests

To run the complete 15-test automated verification suite at any time:

```bash
# macOS / Linux
source venv/bin/activate
python3 -m unittest backend/test_backend.py

# Windows
venv\Scripts\activate
python -m unittest backend\test_backend.py
```

