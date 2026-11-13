# 🔬 NovaBank DBMS Academic Laboratory Manual

> **Course:** Database Management Systems (DBMS) — B.E. CSE (AI&ML)  
> **Interactive Laboratory Guide & Theoretical Foundation**  
> **Engine:** MySQL 8.x / 9.x (InnoDB Engine)  
> **Academic Focus:** Query Optimization, ACID Properties, Concurrency Control, Cursors & Normalization

---

## 📑 Table of Contents
1. [Laboratory Purpose & Pedagogical Architecture](#1-laboratory-purpose--pedagogical-architecture)
2. [Experiment 1: Query Execution Plan (QEP) & Index Optimization](#2-experiment-1-query-execution-plan-qep--index-optimization)
3. [Experiment 2: ACID Atomicity & InnoDB Crash Recovery](#3-experiment-2-acid-atomicity--innodb-crash-recovery)
4. [Experiment 3: ACID Consistency & Schema Integrity Constraints](#4-experiment-3-acid-consistency--schema-integrity-constraints)
5. [Experiment 4: ACID Isolation Levels & Multi-Version Concurrency (MVCC)](#5-experiment-4-acid-isolation-levels--multi-version-concurrency-mvcc)
6. [Experiment 5: Concurrency Control & Deadlock Cycle Detection](#6-experiment-5-concurrency-control--deadlock-cycle-detection)
7. [Experiment 6: Database Cursors in Procedural Stored Procedures](#7-experiment-6-database-cursors-in-procedural-stored-procedures)
8. [Experiment 7: Relational Schema Normalization (1NF through BCNF)](#8-experiment-7-relational-schema-normalization-1nf-through-bcnf)
9. [Viva Voce & Academic Defense Q&A](#9-viva-voce--academic-defense-qa)

---

## 1. Laboratory Purpose & Pedagogical Architecture

Most academic database projects use a database merely as a dumb storage bucket ("CRUD application"), hiding all business rules in backend Python, Java, or JavaScript code. 

**The NovaBank DBMS Academic Laboratory is designed to prove real DBMS mastery.** Embedded directly into the NovaBank web interface is a live, interactive test laboratory that connects in real time to the MySQL InnoDB engine. Every single concept taught in university DBMS syllabi is turned into an interactive, visual experiment:

```
+-----------------------------------------------------------------------------+
|                         NOVA BANK DBMS LIVE LAB                             |
|                                                                             |
|  [Exp 1: EXPLAIN]  [Exp 2: Atomicity]  [Exp 3: Consistency]  [Exp 4: MVCC]  |
|  [Exp 5: Deadlock] [Exp 6: Cursors]    [Exp 7: Normalization]               |
+-----------------------------------------------------------------------------+
                                       │
                    Interactive Stress Testing & Query Triggers
                                       ▼
+-----------------------------------------------------------------------------+
|                     MySQL 8.x Engine Core Validations                       |
|   • Cost-Based Optimizer (QEP)       • Write-Ahead Redo Log (WAL)           |
|   • B-Tree Index Seek vs Table Scan  • InnoDB Row Locks (SELECT FOR UPDATE) |
|   • Snapshot Read & Undo Logs (MVCC) • Wait-For Deadlock Cycle Detector     |
+-----------------------------------------------------------------------------+
```

Students, evaluators, and teachers can run live queries, inject simulated fatal server crashes mid-transfer, force constraint violations, provoke deadlocks, and inspect raw `EXPLAIN FORMAT=JSON` optimizer outputs directly in the UI.

---

## 2. Experiment 1: Query Execution Plan (QEP) & Index Optimization

### Objective
To analyze how the MySQL Cost-Based Optimizer (CBO) evaluates query execution strategies, comparing a Full Table Scan (`ALL`) against an indexed B-Tree seek (`ref` / `range`), and measuring execution cost and latency.

### Academic Theory
When a SQL query is submitted:
1. **Parser & Lexer:** Validates syntax and generates a parse tree.
2. **Cost-Based Optimizer:** Estimates disk I/O and CPU memory costs across competing execution paths using data dictionary table statistics:
   $$\text{Total Cost} = (\text{Pages Read} \times \text{Cost per Page}) + (\text{Rows Evaluated} \times \text{Cost per Row})$$
3. **Execution Engine:** Executes the chosen Query Execution Plan (QEP).

```
Full Table Scan (ALL):
[Disk Block 1] -> [Disk Block 2] -> [Disk Block 3] ... -> [Disk Block N]
O(N) Complexity - High Disk I/O & Memory Pressure

B-Tree Index Seek (ref / range):
        [Root Node]
       /           \
  [Internal]    [Internal]
    /    \        /    \
 [Leaf] [Leaf] [Leaf] [Leaf] -> Direct Row Pointer (Clustered Index PK)
O(log N) Complexity - Minimal Disk Reads
```

### Lab Presets & Benchmarks
In the DBMS Lab, table `query_demo_data` is pre-populated with 2,500 records:

| Preset Experiment | SQL Query | Access Type | Rows Examined | Cost Estimate | Latency |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Preset A: Unindexed Scan** | `SELECT * FROM query_demo_data WHERE unindexed_tag = 'TAG-0042' LIMIT 50;` | `ALL` (Table Scan) | **2,500 rows** | ~258.00 | ~4.5 ms |
| **Preset B: Indexed B-Tree Seek** | `SELECT * FROM query_demo_data WHERE indexed_tag = 'TAG-0042' LIMIT 50;` | `ref` (Index Seek) | **25 rows** | ~8.75 | ~0.5 ms |
| **Preset C: Composite Index** | `SELECT * FROM query_demo_data WHERE city = 'Mumbai' AND amount > 25000 LIMIT 50;` | `range` | **30-40 rows** | ~14.20 | ~0.8 ms |
| **Preset D: Relational JOIN** | `SELECT c.customer_number, a.account_number FROM customers c JOIN accounts a ...` | `eq_ref` | Logarithmic seek | Indexed | ~0.9 ms |

### How to Run in the UI
1. Click **DBMS Live Lab** on the sidebar navigation.
2. Click **Preset A: Unindexed Scan (ALL)**, then click **Execute Query & Analyze Plan**.
3. Note the access type `ALL` and high row scan count.
4. Click **Preset B: Indexed B-Tree Seek**, then click execute.
5. Watch the access type immediately switch to `ref` with rows examined dropping from 2,500 to 25.

---

## 3. Experiment 2: ACID Atomicity & InnoDB Crash Recovery

### Objective
To validate the **"All or Nothing"** property of ACID transactions, proving that an unexpected failure or crash mid-transaction leaves the database in its original clean state with zero balance loss or duplication.

### Academic Theory
- **Atomicity:** A multi-step transaction is treated as a single indivisible unit of work. If any step fails, all preceding modifications are reversed using the InnoDB **Undo Log** and **Write-Ahead Logging (WAL)**.
- **Financial Invariance Principle:** In any internal transfer between Account $A$ and Account $B$:
  $$\text{Balance}(A)_{\text{initial}} + \text{Balance}(B)_{\text{initial}} = \text{Balance}(A)_{\text{final}} + \text{Balance}(B)_{\text{final}}$$

### Lab Simulation Setup
The lab executes a two-step transfer of ₹1,000 from Account $A$ (Kush Dalal) to Account $B$ (Priya Sharma):
- **Step 1:** Debit ₹1,000 from Account $A$.
- **Simulated Interrupt:** You toggle **Simulate Fatal Crash Mid-Transfer?** to `YES`.
- **Step 2:** The system triggers an intentional exception (`SQLSTATE '45000'`) before Account $B$ can be credited.

```
Without Atomicity (System Bug):
Account A (-₹1,000) ---> [CRASH] -X-> Account B (+₹0) => ₹1,000 PERMANENTLY LOST!

With InnoDB Atomicity (NovaBank):
Account A (-₹1,000) ---> [CRASH] ---> ENGINE ROLLBACK ---> Account A Restored (+₹1,000)
Net Money Lost = ₹0.00 (Invariance Preserved!)
```

### Lab Verification Metrics
The UI displays the dynamic stepper and live invariance check:
- `Initial Pool Balance: ₹3,00,000.00`
- `Final Pool Balance: ₹3,00,000.00`
- `Status: Perfect Invariance Maintained. Zero money lost or created.`

---

## 4. Experiment 3: ACID Consistency & Schema Integrity Constraints

### Objective
To verify that the database engine enforces schema integrity rules at the kernel level, blocking illegal data entry regardless of what the application attempts.

### Academic Theory
Consistency guarantees that the database transitions strictly from one valid state to another, upholding:
1. **Domain Integrity:** Data types and range constraints (`CHECK`).
2. **Entity Integrity:** Candidate keys and uniqueness (`PRIMARY KEY`, `UNIQUE`).
3. **Referential Integrity:** Foreign key relationships and cascade rules (`FOREIGN KEY ... ON DELETE RESTRICT`).

### Interactive Test Scenarios in Lab

| Experiment | Attempted Action | Enforcing Rule | MySQL Engine Result |
| :--- | :--- | :--- | :--- |
| **Negative Balance** | Attempting to withdraw funds dropping balance below ₹1,000.00 minimum threshold. | `trg_accounts_before_update` + `CHECK (balance >= 0.00)` | **BLOCKED:** `ERROR 1644 (45000): Cannot decrease balance below minimum threshold.` |
| **Duplicate National ID** | Registering a new customer with an already registered PAN Card. | `UNIQUE KEY uq_customer_national_id` | **BLOCKED:** `ERROR 1062 (23000): Duplicate entry 'ABCDE1234F' for key 'national_id'.` |
| **Referential Integrity** | Attempting to delete customer ID 1 who owns active bank accounts. | `FOREIGN KEY ... ON DELETE RESTRICT` | **BLOCKED:** `ERROR 1451 (23000): Cannot delete parent row: a foreign key constraint fails.` |

---

## 5. Experiment 4: ACID Isolation Levels & Multi-Version Concurrency (MVCC)

### Objective
To evaluate transaction isolation levels and explain how MySQL InnoDB uses Multi-Version Concurrency Control (MVCC) and Next-Key row locks to eliminate concurrency anomalies.

### Academic Matrix of Concurrency Anomalies

| Isolation Level | Dirty Read | Non-Repeatable Read | Phantom Read | Lock Overhead |
| :--- | :---: | :---: | :---: | :--- |
| **READ UNCOMMITTED** | Allowed | Allowed | Allowed | None (Reads uncommitted dirty memory) |
| **READ COMMITTED** | Prevented | Allowed | Allowed | Low (Read snapshot taken per statement) |
| **REPEATABLE READ (MySQL Default)** | Prevented | Prevented | **Prevented** | **Balanced (Read snapshot at txn start + Next-Key locks)** |
| **SERIALIZABLE** | Prevented | Prevented | Prevented | High (Pessimistic S-locks on all SELECTs) |

### Why MySQL Defaults to REPEATABLE READ
Under ANSI SQL, `REPEATABLE READ` allows Phantom Reads. However, **MySQL InnoDB prevents Phantom Reads** by using **Next-Key Locks** (combining index-record locks with gap locks) during locking reads, and MVCC snapshot read views during non-locking `SELECT` statements!

---

## 6. Experiment 5: Concurrency Control & Deadlock Cycle Detection

### Objective
To demonstrate the classic database dining-philosophers problem (deadlock) caused by reverse-order locking, and showcase how InnoDB's Wait-For Graph cycle detector intervenes.

### Academic Theory
A **Deadlock** occurs when two or more transactions have a mutual cyclic dependency:
- Transaction 1 holds a lock on Account 1 and requests a lock on Account 2.
- Transaction 2 holds a lock on Account 2 and requests a lock on Account 1.

```
Wait-For Graph (Cycle Detected):
[Transaction 1] --holds lock on Acc 1--> waits for Acc 2 --> [Transaction 2]
       ^                                                            │
       └------------------- waits for Acc 1 ------------------------┘
```

### The Live Simulation in NovaBank Lab
When you click **Simulate Concurrent Deadlock**:
1. Worker Thread A opens a transaction and issues:  
   `SELECT * FROM accounts WHERE account_id = 1 FOR UPDATE;`
2. Simultaneously, Worker Thread B opens a transaction and issues:  
   `SELECT * FROM accounts WHERE account_id = 2 FOR UPDATE;`
3. Both threads sleep for 400 milliseconds to simulate concurrent network delay.
4. Thread A attempts to acquire lock on Account 2, while Thread B attempts to acquire lock on Account 1.
5. **Engine Intervention:** InnoDB detects the cycle in its internal Wait-For graph, selects the transaction with fewer undo log records as the **deadlock victim**, aborts it with:  
   `ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction`,  
   and allows the other transaction to commit cleanly!

### How NovaBank Eliminates Deadlocks in Production
In stored procedure `sp_transfer_funds`, NovaBank applies **Deterministic Lock Ordering**:
```sql
IF v_from_id < v_to_id THEN
    SELECT ... WHERE account_id = v_from_id FOR UPDATE;
    SELECT ... WHERE account_id = v_to_id FOR UPDATE;
ELSE
    SELECT ... WHERE account_id = v_to_id FOR UPDATE;
    SELECT ... WHERE account_id = v_from_id FOR UPDATE;
END IF;
```
Because every transaction locks accounts in strictly ascending numeric order, a circular wait cycle is mathematically impossible!

---

## 7. Experiment 6: Database Cursors in Procedural Stored Procedures

### Objective
To demonstrate sequential row-by-row iteration using a database `CURSOR` inside stored procedure `sp_monthly_interest_accrual`.

### Academic Theory
While relational SQL is primarily set-oriented, certain batch accounting workflows (such as individual savings interest calculation and amortized ledger writes) require procedural cursor traversal:
1. `DECLARE cur_name CURSOR FOR SELECT ...;`
2. `DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;`
3. `OPEN cur_name;`
4. `FETCH cur_name INTO var1, var2;`
5. Process record in loop until `done = TRUE`.
6. `CLOSE cur_name;`

### Execution in NovaBank
Clicking **Trigger Interest Accrual Batch** invokes `sp_monthly_interest_accrual`. The cursor loops across all active Savings accounts, calculates monthly accrued interest ($4.50\%$ annual rate divided by 12), credits each balance, and inserts an audit transaction row for every account atomically.

---

## 8. Experiment 7: Relational Schema Normalization (1NF through BCNF)

### Normalization Hierarchy

```
[Unnormalized Data] 
       │  Atomic values, no repeating groups
       ▼
[1st Normal Form (1NF)]
       │  Remove Partial Functional Dependencies (Full PK dependency)
       ▼
[2nd Normal Form (2NF)]
       │  Remove Transitive Functional Dependencies (X -> Y -> Z)
       ▼
[3rd Normal Form (3NF)]
       │  Every determinant is a candidate key
       ▼
[Boyce-Codd Normal Form (BCNF)]
```

### NovaBank Normalization Breakdown

1. **First Normal Form (1NF):**
   - Every column contains atomic (indivisible) scalar values.
   - Repeating multi-valued groups (e.g., multiple phone numbers or account records) are normalized into child tables (`accounts`, `cards`).
2. **Second Normal Form (2NF):**
   - The schema is in 1NF and contains **no partial dependencies**.
   - In composite-key tables like `beneficiaries` or `loan_payments`, every non-prime attribute depends on the complete primary key.
3. **Third Normal Form (3NF):**
   - The schema is in 2NF and contains **no transitive dependencies**.
   - In `accounts`, branch metadata (`branch_name`, `city`, `address`) is not stored directly on the account. Instead, `branch_id` references the `branches` master table.
4. **Boyce-Codd Normal Form (BCNF):**
   - In every functional dependency $X \to Y$, the determinant $X$ is a superkey.
   - Guarantees zero update, insertion, or deletion anomalies across all 11 tables.

---

## 9. Viva Voce & Academic Defense Q&A

**Q1: Why use stored procedures instead of putting business logic in Python?**  
*Answer:* Stored procedures execute inside the database engine memory space, drastically reducing network round-trips. More importantly, they execute transactions atomically with row-level locks and rollback handlers, preventing race conditions that application code cannot reliably handle.

**Q2: What is the difference between an unindexed table scan and an index seek?**  
*Answer:* An unindexed query inspects every single block on disk ($O(N)$), leading to high disk I/O. A B-Tree index seek traverses balanced tree nodes in logarithmic time ($O(\log N)$) using key pointers.

**Q3: How does InnoDB handle deadlocks?**  
*Answer:* InnoDB continuously maintains an internal Wait-For Graph. When a directed cycle is detected, the engine aborts the transaction with the smaller weight (fewer rows modified) and emits `ERROR 1213`.

**Q4: How does NovaBank guarantee zero financial loss during a server crash?**  
*Answer:* NovaBank wraps transfers in ACID transactions (`START TRANSACTION ... COMMIT`). If a crash occurs mid-transfer, InnoDB's Write-Ahead Log (WAL) and Undo tablespace automatically roll back all partial writes on restart, maintaining balance invariance.
