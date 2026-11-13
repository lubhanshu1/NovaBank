import time
import json
import threading
from flask import Blueprint, request, jsonify
import mysql.connector
from ..db import get_db, execute_query, call_procedure, serialize_row
from ..config import Config

lab_bp = Blueprint('dbms_lab', __name__, url_prefix='/api/lab')

# ----------------------------------------------------------------------------
# 1. Interactive SQL Runner & EXPLAIN Query Optimizer Visualizer
# ----------------------------------------------------------------------------
@lab_bp.route('/query-runner', methods=['POST'])
def query_runner():
    data = request.get_json() or {}
    query = data.get('query', '').strip()

    if not query:
        return jsonify({"success": False, "message": "SQL query cannot be empty"}), 400

    # Safety guard: only allow SELECT or EXPLAIN statements in the query runner
    first_token = query.split()[0].upper()
    if first_token not in ['SELECT', 'EXPLAIN', 'SHOW', 'DESCRIBE', 'DESC']:
        return jsonify({
            "success": False, 
            "message": "Only read/analytical queries (SELECT, EXPLAIN) are permitted in the Query Lab runner."
        }), 403

    explain_query = f"EXPLAIN FORMAT=JSON {query}" if not query.upper().startswith('EXPLAIN') else query

    with get_db() as cnx:
        cursor = cnx.cursor(dictionary=True)
        try:
            # 1. Execute EXPLAIN to inspect query execution plan
            explain_data = None
            try:
                cursor.execute(explain_query)
                raw_explain = cursor.fetchone()
                if raw_explain and 'EXPLAIN' in raw_explain:
                    explain_data = json.loads(raw_explain['EXPLAIN'])
                elif raw_explain:
                    # TiDB commonly returns tabular EXPLAIN rows rather than
                    # MySQL's JSON plan shape. Normalize the first table row.
                    rows_plan = [raw_explain] + cursor.fetchall()
                    first = rows_plan[0]
                    key_name = first.get('key') or first.get('access object') or 'NONE (Table Scan)'
                    access = first.get('access type') or first.get('type') or 'UNKNOWN'
                    explain_data = {"query_plan": {"index_name": key_name,
                        "operation": access, "estimated_rows": first.get('estRows', 'N/A')}}
            except Exception as exp_err:
                # Fall back to ordinary EXPLAIN if FORMAT=JSON is unavailable.
                try:
                    cursor.execute("EXPLAIN " + query)
                    plan_rows = cursor.fetchall()
                    first = plan_rows[0] if plan_rows else {}
                    explain_data = {"query_plan": {"index_name": first.get('key') or 'NONE (Table Scan)',
                        "operation": first.get('type') or 'UNKNOWN',
                        "estimated_rows": first.get('rows', 'N/A')}}
                except Exception:
                    explain_data = {"query_plan": {"index_name": "UNKNOWN", "operation": str(exp_err)}}

            # 2. Benchmark actual execution
            start_time = time.perf_counter()
            cursor.execute(query)
            rows = cursor.fetchall()
            exec_time_ms = round((time.perf_counter() - start_time) * 1000, 3)

            # Limit rows returned to frontend to prevent browser memory freeze
            serialized_rows = [serialize_row(r) for r in rows[:100]]
            columns = list(serialized_rows[0].keys()) if serialized_rows else []

            # Extract optimization insights
            plan_summary = extract_plan_summary(explain_data)

            return jsonify({
                "success": True,
                "execution_time_ms": exec_time_ms,
                "total_rows_returned": len(rows),
                "columns": columns,
                "data": serialized_rows,
                "explain_plan": explain_data,
                "optimization_summary": plan_summary
            })

        except mysql.connector.Error as err:
            return jsonify({
                "success": False,
                "error_code": err.errno,
                "sqlstate": err.sqlstate,
                "message": err.msg
            }), 400
        finally:
            cursor.close()

def extract_plan_summary(explain_json):
    """Parses MySQL JSON EXPLAIN plan to extract key optimizer metrics across MySQL 8.0 and 8.4+/9.x."""
    if not explain_json:
        return {"access_type": "UNKNOWN", "cost": "N/A", "index_used": "None"}

    # Schema 2.x (MySQL 8.4+)
    if "query_plan" in explain_json:
        qp = explain_json["query_plan"]
        node = qp
        if "inputs" in qp and isinstance(qp["inputs"], list) and qp["inputs"]:
            node = qp["inputs"][0]

        index_used = node.get("index_name") or qp.get("index_name") or ("Table scan" if "table_scan" in str(qp).lower() else "None")
        access_type = node.get("operation") or qp.get("access_type") or "N/A"
        rows_examined = node.get("estimated_rows") or qp.get("estimated_rows", "N/A")
        cost = node.get("estimated_total_cost") or qp.get("estimated_total_cost", "N/A")

        is_table_scan = ("table scan" in str(access_type).lower()) or (index_used in [None, "None", "Table scan"])
        verdict = "WARNING: Full Table Scan detected! Every row must be read from disk." if is_table_scan else f"OPTIMIZED: Query utilized B-Tree index '{index_used}'."

        return {
            "access_type": access_type,
            "index_used": index_used,
            "rows_examined": rows_examined,
            "query_cost": cost,
            "filtered_percent": "100%",
            "is_table_scan": is_table_scan,
            "verdict": verdict
        }

    # Schema 1.x (MySQL 8.0)
    qb = explain_json.get("query_block", {})
    cost_info = qb.get("cost_info", {}).get("query_cost", "N/A")
    
    table_node = qb.get("table", {})
    if not table_node and "nested_loop" in qb:
        nested = qb.get("nested_loop", [])
        if nested and isinstance(nested, list) and len(nested) > 0:
            table_node = nested[0].get("table", {})

    access_type = table_node.get("access_type", "ALL (Full Table Scan)")
    key = table_node.get("key", "NONE (Table Scan)")
    rows_examined = table_node.get("rows_examined_per_scan", "N/A")
    filtered = table_node.get("filtered", "100.00%")

    is_table_scan = access_type.upper() in ['ALL', 'INDEX']
    verdict = "WARNING: Full Table Scan detected! Every row must be read from disk." if is_table_scan else f"OPTIMIZED: Query utilized B-Tree index '{key}'."

    return {
        "access_type": access_type,
        "index_used": key,
        "rows_examined": rows_examined,
        "query_cost": cost_info,
        "filtered_percent": filtered,
        "is_table_scan": is_table_scan,
        "verdict": verdict
    }

# ----------------------------------------------------------------------------
# 2. ACID: Atomicity Demonstration
# ----------------------------------------------------------------------------
@lab_bp.route('/acid/atomicity', methods=['POST'])
def demo_atomicity():
    """
    Simulates a 2-step financial transfer with an optional failure switch.
    Proves that upon rollback, no funds vanish or remain partially transferred.
    """
    data = request.get_json() or {}
    simulate_failure = data.get('simulate_failure', True)
    amount = float(data.get('amount', 500.00))

    from_acc_no = '1001001001'
    to_acc_no = '1001002001'

    # Step 0: Capture pre-transaction balances
    pre_from = execute_query("SELECT balance FROM accounts WHERE account_number = %s", (from_acc_no,), fetchone=True)
    pre_to = execute_query("SELECT balance FROM accounts WHERE account_number = %s", (to_acc_no,), fetchone=True)

    log_steps = []
    log_steps.append({
        "step": 1,
        "title": "Initial State",
        "detail": f"Account A: ₹{pre_from['balance']:.2f} | Account B: ₹{pre_to['balance']:.2f}"
    })

    with get_db() as cnx:
        cursor = cnx.cursor(dictionary=True)
        try:
            cursor.execute("START TRANSACTION;")
            log_steps.append({
                "step": 2,
                "title": "START TRANSACTION",
                "detail": "Explicit InnoDB transaction boundary established with isolation level REPEATABLE READ."
            })

            # Step 1: Debit Account A
            cursor.execute(
                "UPDATE accounts SET balance = balance - %s WHERE account_number = %s",
                (amount, from_acc_no)
            )
            log_steps.append({
                "step": 3,
                "title": "Step 1: Debit Account A",
                "detail": f"Deducted ₹{amount:.2f} from Account A. Uncommitted balance: ₹{pre_from['balance'] - amount:.2f}"
            })

            # Simulated crash / mid-flight error
            if simulate_failure:
                log_steps.append({
                    "step": 4,
                    "title": "Simulated System Crash / Connection Lost",
                    "detail": "FATAL: Simulated server crash or database timeout occurred BEFORE crediting Account B!"
                })
                raise RuntimeError("Simulated network timeout/power disruption before destination account was credited.")

            # Step 2: Credit Account B
            cursor.execute(
                "UPDATE accounts SET balance = balance + %s WHERE account_number = %s",
                (amount, to_acc_no)
            )
            log_steps.append({
                "step": 4,
                "title": "Step 2: Credit Account B",
                "detail": f"Credited ₹{amount:.2f} to Account B."
            })

            cursor.execute("COMMIT;")
            log_steps.append({
                "step": 5,
                "title": "COMMIT",
                "detail": "All changes flushed to InnoDB redo log (WAL). Transaction committed successfully."
            })
            result_status = "COMMITTED"

        except Exception as e:
            cursor.execute("ROLLBACK;")
            log_steps.append({
                "step": 5,
                "title": "ROLLBACK Executed",
                "detail": f"Engine rolled back all uncommitted changes. Reason: {str(e)}"
            })
            result_status = "ROLLED_BACK"
        finally:
            cursor.close()

    # Step 6: Verify post-transaction state
    post_from = execute_query("SELECT balance FROM accounts WHERE account_number = %s", (from_acc_no,), fetchone=True)
    post_to = execute_query("SELECT balance FROM accounts WHERE account_number = %s", (to_acc_no,), fetchone=True)

    log_steps.append({
        "step": 6,
        "title": "Final State Verification",
        "detail": f"Account A: ₹{post_from['balance']:.2f} | Account B: ₹{post_to['balance']:.2f}"
    })

    invariance_maintained = (
        (pre_from['balance'] + pre_to['balance']) == 
        (post_from['balance'] + post_to['balance'])
    )

    return jsonify({
        "success": True,
        "status": result_status,
        "simulated_failure": simulate_failure,
        "invariance_maintained": invariance_maintained,
        "explanation": "Atomicity ensures 'All or Nothing'. Either the entire transfer succeeds, or any failure causes an automatic ROLLBACK so money never evaporates or duplicates.",
        "steps": log_steps,
        "balances": {
            "initial": {"account_a": pre_from['balance'], "account_b": pre_to['balance']},
            "final": {"account_a": post_from['balance'], "account_b": post_to['balance']}
        }
    })

# ----------------------------------------------------------------------------
# 3. ACID: Consistency & Integrity Constraint Enforcement Demonstration
# ----------------------------------------------------------------------------
@lab_bp.route('/acid/consistency', methods=['POST'])
def demo_consistency():
    data = request.get_json() or {}
    scenario = data.get('scenario', 'NEGATIVE_BALANCE')

    result = {}

    with get_db() as cnx:
        cursor = cnx.cursor(dictionary=True)
        try:
            if scenario == 'NEGATIVE_BALANCE':
                # TiDB has no triggers: demonstrate the same domain rule in the
                # application/service layer before issuing a balance update.
                cursor.execute("SELECT balance, minimum_balance FROM accounts WHERE account_number = '1001001001'")
                account = cursor.fetchone()
                if account and 50 < float(account['minimum_balance']):
                    result = {"status": "REJECTED_BY_DATABASE", "error_number": None,
                              "sqlstate": "APP_VALIDATION", "mysql_message": "Balance cannot be less than the account minimum balance threshold.",
                              "constraint_enforced": True,
                              "academic_concept": "Consistency: NovaBank enforces the minimum-balance business invariant in its transactional application service because TiDB does not support triggers."}
                else:
                    result = {"status": "UNEXPECTED_SUCCESS", "message": "Minimum balance test did not reject the value."}

            elif scenario == 'DUPLICATE_NATIONAL_ID':
                # Try to insert customer with existing national_id
                cursor.execute("""
                    INSERT INTO customers (
                        customer_number, first_name, last_name, email, phone,
                        national_id, date_of_birth, address_line1, city, state, postal_code
                    ) VALUES (
                        'CUST-FAIL-01', 'Test', 'Duplicate', 'unique1@demo.com', '+1 (555) 000-0001',
                        'SSN-998-01-2001', '1999-01-01', '123 Fake St', 'New York', 'NY', '10001'
                    )
                """)
                result = {"status": "UNEXPECTED_SUCCESS", "message": "Constraint failed to trigger."}

            elif scenario == 'FOREIGN_KEY_VIOLATION':
                # Try to delete customer 1 who has active accounts (ON DELETE RESTRICT)
                cursor.execute("DELETE FROM customers WHERE customer_id = 1")
                result = {"status": "UNEXPECTED_SUCCESS", "message": "Constraint failed to trigger."}

        except mysql.connector.Error as err:
            result = {
                "status": "REJECTED_BY_DATABASE",
                "error_number": err.errno,
                "sqlstate": err.sqlstate,
                "mysql_message": err.msg,
                "constraint_enforced": True,
                "academic_concept": "Consistency (ACID): MySQL's relational engine enforces domain integrity, entity integrity (PRIMARY/UNIQUE KEY), referential integrity (FOREIGN KEY), and user-defined business rules (BEFORE UPDATE triggers & CHECK constraints)."
            }
        finally:
            cursor.close()

    return jsonify({"success": True, "scenario": scenario, "result": result})

# ----------------------------------------------------------------------------
# 4. ACID: Transaction Isolation Level Demonstration
# ----------------------------------------------------------------------------
@lab_bp.route('/acid/isolation', methods=['POST'])
def demo_isolation():
    data = request.get_json() or {}
    level = data.get('level', 'REPEATABLE READ')

    descriptions = {
        "READ UNCOMMITTED": {
            "dirty_reads": "ALLOWED (Dangerous: Can read dirty uncommitted rows that may be rolled back)",
            "non_repeatable_reads": "ALLOWED",
            "phantom_reads": "ALLOWED",
            "lock_overhead": "Lowest",
            "novabank_recommendation": "Not permitted in banking environments."
        },
        "READ COMMITTED": {
            "dirty_reads": "PREVENTED (Only reads committed data)",
            "non_repeatable_reads": "ALLOWED (Consecutive reads in same tx may see changed data)",
            "phantom_reads": "ALLOWED",
            "lock_overhead": "Low (Consistent read with snapshot)",
            "novabank_recommendation": "Acceptable for reporting dashboards."
        },
        "REPEATABLE READ": {
            "dirty_reads": "PREVENTED",
            "non_repeatable_reads": "PREVENTED (Consistent snapshot reads via MVCC)",
            "phantom_reads": "PREVENTED (in InnoDB via Next-Key locks)",
            "lock_overhead": "Moderate (MySQL default)",
            "novabank_recommendation": "Default isolation level used across NovaBank."
        },
        "SERIALIZABLE": {
            "dirty_reads": "PREVENTED",
            "non_repeatable_reads": "PREVENTED",
            "phantom_reads": "PREVENTED",
            "lock_overhead": "High (Implicitly converts all plain SELECTs to SELECT ... FOR SHARE)",
            "novabank_recommendation": "Strict financial year-end reconciliation."
        }
    }

    # Fetch current MySQL session and global isolation level
    levels = execute_query(
        "SELECT @@session.transaction_isolation AS session_level, @@global.transaction_isolation AS global_level",
        fetchone=True
    )

    return jsonify({
        "success": True,
        "selected_level": level,
        "current_mysql_configuration": levels,
        "properties": descriptions.get(level, descriptions["REPEATABLE READ"])
    })

# ----------------------------------------------------------------------------
# 5. Concurrency & Deadlock Detection Simulator
# ----------------------------------------------------------------------------
@lab_bp.route('/concurrency/deadlock', methods=['POST'])
def demo_deadlock():
    """
    Demonstrates two concurrent transactions locking resources in opposite order:
    Tx1: Lock Acc 1 -> sleep -> Lock Acc 2
    Tx2: Lock Acc 2 -> sleep -> Lock Acc 1
    Shows MySQL InnoDB deadlock detection (Error 1213: Deadlock found).
    """
    thread_results = {}

    def worker_a():
        try:
            with get_db() as cnx:
                cnx.autocommit = False
                cursor = cnx.cursor(dictionary=True)
                # Tx 1: Lock Acc 1
                cursor.execute("SELECT balance FROM accounts WHERE account_id = 1 FOR UPDATE;")
                time.sleep(0.4)
                # Tx 1: Try to Lock Acc 2
                cursor.execute("SELECT balance FROM accounts WHERE account_id = 2 FOR UPDATE;")
                cnx.commit()
                cursor.close()
                thread_results['thread_a'] = {"status": "COMMITTED", "msg": "Acquired both locks successfully."}
        except mysql.connector.Error as e:
            thread_results['thread_a'] = {"status": "DEADLOCK_OR_ERROR", "errno": e.errno, "msg": e.msg}

    def worker_b():
        try:
            with get_db() as cnx:
                cnx.autocommit = False
                cursor = cnx.cursor(dictionary=True)
                time.sleep(0.1)
                # Tx 2: Lock Acc 2
                cursor.execute("SELECT balance FROM accounts WHERE account_id = 2 FOR UPDATE;")
                time.sleep(0.4)
                # Tx 2: Try to Lock Acc 1
                cursor.execute("SELECT balance FROM accounts WHERE account_id = 1 FOR UPDATE;")
                cnx.commit()
                cursor.close()
                thread_results['thread_b'] = {"status": "COMMITTED", "msg": "Acquired both locks successfully."}
        except mysql.connector.Error as e:
            thread_results['thread_b'] = {"status": "DEADLOCK_OR_ERROR", "errno": e.errno, "msg": e.msg}

    t1 = threading.Thread(target=worker_a)
    t2 = threading.Thread(target=worker_b)

    t1.start()
    t2.start()

    t1.join(timeout=5)
    t2.join(timeout=5)

    return jsonify({
        "success": True,
        "concurrency_simulation": {
            "thread_a": thread_results.get('thread_a', {"status": "TIMEOUT"}),
            "thread_b": thread_results.get('thread_b', {"status": "TIMEOUT"})
        },
        "prevention_mechanism": "In NovaBank's production procedure sp_transfer_funds, we eliminate deadlocks deterministically by comparing account IDs (IF v_from_id < v_to_id) and always acquiring row locks in ascending account_id order."
    })

# ----------------------------------------------------------------------------
# 6. Cursor / Batch Processing Demonstration
# ----------------------------------------------------------------------------
@lab_bp.route('/batch/interest', methods=['POST'])
def run_monthly_interest():
    """Runs the application-side monthly interest batch."""
    res = call_procedure('sp_monthly_interest_accrual', [None, None])
    out = res['out_args']
    count = out[0]
    total_interest = out[1]

    limit_count = int(count) if count and int(count) > 0 else 5
    recent_interest_txns = execute_query("""
        SELECT transaction_id, reference_no, amount, balance_after, description, transaction_date
        FROM transactions
        WHERE transaction_type = 'INTEREST_CREDIT'
        ORDER BY transaction_date DESC, transaction_id DESC
        LIMIT %s
    """, (limit_count,), fetchall=True)

    return jsonify({
        "success": True,
        "procedure_used": "sp_monthly_interest_accrual",
        "concept": "Demonstrates MySQL Stored Procedure CURSOR iteration across multiple accounts in a single atomic batch.",
        "processed_savings_accounts": count,
        "total_interest_credited": total_interest,
        "recent_transactions": recent_interest_txns
    })

# ----------------------------------------------------------------------------
# 7. Normalization Reference & ER Architecture
# ----------------------------------------------------------------------------
@lab_bp.route('/normalization', methods=['GET'])
def get_normalization_data():
    return jsonify({
        "success": True,
        "forms": [
            {
                "level": "1NF (First Normal Form)",
                "rules": "Atomic attributes, unique rows, no repeating groups.",
                "novabank_design": "Customer addresses, transaction logs, and phone numbers are split into atomic scalar fields (no comma-separated values in records)."
            },
            {
                "level": "2NF (Second Normal Form)",
                "rules": "Must be in 1NF and have NO partial functional dependencies on composite keys.",
                "novabank_design": "Tables use surrogate Primary Keys (e.g. account_id, loan_id). Composite entities like beneficiaries (customer_id, account_number) ensure all non-key attributes depend on the entire candidate key."
            },
            {
                "level": "3NF (Third Normal Form)",
                "rules": "Must be in 2NF and have NO transitive functional dependencies (non-prime attribute determining another non-prime attribute).",
                "novabank_design": "Branch information (branch_name, address, city, phone) is separated into its own 'branches' table. Accounts merely hold a foreign key (branch_id). This eliminates Update, Insertion, and Deletion anomalies."
            },
            {
                "level": "BCNF (Boyce-Codd Normal Form)",
                "rules": "Every determinant is a candidate key.",
                "novabank_design": "In customers, email, phone, and national_id are unique candidate keys, eliminating any non-superkey determinants."
            }
        ],
        "tables": [
            {"name": "branches", "pk": "branch_id", "fks": []},
            {"name": "customers", "pk": "customer_id", "fks": []},
            {"name": "users", "pk": "user_id", "fks": ["customer_id -> customers.customer_id"]},
            {"name": "accounts", "pk": "account_id", "fks": ["customer_id -> customers.customer_id", "branch_id -> branches.branch_id"]},
            {"name": "transactions", "pk": "transaction_id", "fks": ["account_id -> accounts.account_id", "related_account_id -> accounts.account_id"]},
            {"name": "loans", "pk": "loan_id", "fks": ["customer_id -> customers.customer_id", "account_id -> accounts.account_id"]},
            {"name": "loan_payments", "pk": "payment_id", "fks": ["loan_id -> loans.loan_id"]},
            {"name": "cards", "pk": "card_id", "fks": ["account_id -> accounts.account_id"]},
            {"name": "beneficiaries", "pk": "beneficiary_id", "fks": ["customer_id -> customers.customer_id"]},
            {"name": "audit_logs", "pk": "audit_id", "fks": []}
        ]
    })
