from flask import Blueprint, request, jsonify, session
from ..db import execute_query, call_procedure

accounts_bp = Blueprint('accounts', __name__, url_prefix='/api/accounts')

@accounts_bp.route('', methods=['GET'])
def list_accounts():
    customer_id = request.args.get('customer_id')
    role = session.get('role')
    user_cust_id = session.get('customer_id')

    # If logged in as customer, strictly scope to their accounts
    if role == 'CUSTOMER' and user_cust_id:
        customer_id = user_cust_id

    sql = """
        SELECT 
            a.account_id,
            a.account_number,
            a.account_type,
            a.balance,
            a.minimum_balance,
            a.interest_rate,
            a.currency,
            a.status,
            a.opened_date,
            c.customer_id,
            c.customer_number,
            CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
            c.email AS customer_email,
            c.customer_tier,
            b.branch_name,
            b.branch_code,
            b.city AS branch_city
        FROM accounts a
        JOIN customers c ON a.customer_id = c.customer_id
        JOIN branches b ON a.branch_id = b.branch_id
    """
    params = []
    if customer_id:
        sql += " WHERE a.customer_id = %s"
        params.append(customer_id)

    sql += " ORDER BY a.balance DESC, a.account_id ASC"

    accounts = execute_query(sql, params, fetchall=True)
    return jsonify({"success": True, "count": len(accounts), "accounts": accounts})

@accounts_bp.route('/<account_number>', methods=['GET'])
def get_account_detail(account_number):
    account = execute_query("""
        SELECT 
            a.*,
            c.customer_number,
            CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
            c.email,
            c.phone,
            c.customer_tier,
            c.kyc_status,
            b.branch_name,
            b.branch_code,
            b.address AS branch_address,
            b.city AS branch_city
        FROM accounts a
        JOIN customers c ON a.customer_id = c.customer_id
        JOIN branches b ON a.branch_id = b.branch_id
        WHERE a.account_number = %s
    """, (account_number,), fetchone=True)

    if not account:
        return jsonify({"success": False, "message": "Account not found"}), 404

    # Fetch recent transactions for this account
    recent_txns = execute_query("""
        SELECT 
            transaction_id, reference_no, transaction_type, amount,
            balance_before, balance_after, status, channel, description,
            transaction_date
        FROM transactions
        WHERE account_id = %s
        ORDER BY transaction_date DESC, transaction_id DESC
        LIMIT 20
    """, (account['account_id'],), fetchall=True)

    # Fetch cards linked to this account
    cards = execute_query("""
        SELECT card_id, card_number_masked, card_type, card_brand, expiry_date, daily_limit, status
        FROM cards
        WHERE account_id = %s
    """, (account['account_id'],), fetchall=True)

    return jsonify({
        "success": True,
        "account": account,
        "recent_transactions": recent_txns,
        "cards": cards
    })

@accounts_bp.route('', methods=['POST'])
def open_account():
    """Opens a new bank account through the transactional application service."""
    data = request.get_json() or {}
    customer_id = data.get('customer_id')
    branch_id = data.get('branch_id', 1)
    account_type = data.get('account_type', 'SAVINGS').upper()
    initial_deposit = float(data.get('initial_deposit', 1000.00))
    interest_rate = float(data.get('interest_rate', 3.50))
    min_balance = float(data.get('minimum_balance', 500.00))

    if not customer_id:
        return jsonify({"success": False, "message": "Customer ID is required"}), 400

    # Stored procedure parameters:
    # (IN customer_id, IN branch_id, IN account_type, IN initial_deposit, IN interest_rate, IN min_balance,
    #  OUT account_no, OUT status, OUT message)
    res = call_procedure('sp_open_account', [
        customer_id, branch_id, account_type, initial_deposit, interest_rate, min_balance,
        None, None, None
    ])

    out = res['out_args']
    account_no = out[6]
    status = out[7]
    message = out[8]

    if status == 'SUCCESS':
        return jsonify({
            "success": True,
            "message": message,
            "account_number": account_no,
            "procedure_used": "sp_open_account"
        }), 201
    else:
        return jsonify({
            "success": False,
            "message": message,
            "procedure_used": "sp_open_account"
        }), 400

@accounts_bp.route('/<account_number>/status', methods=['POST'])
def update_status(account_number):
    data = request.get_json() or {}
    new_status = data.get('status', '').upper()

    if new_status not in ['ACTIVE', 'FROZEN', 'DORMANT', 'CLOSED']:
        return jsonify({"success": False, "message": "Invalid status value"}), 400

    res = execute_query(
        "UPDATE accounts SET status = %s WHERE account_number = %s",
        (new_status, account_number),
        commit=True
    )

    if res['affected_rows'] == 0:
        return jsonify({"success": False, "message": "Account not found or status unchanged"}), 404

    return jsonify({
        "success": True,
        "message": f"Account {account_number} status updated to {new_status}."
    })

@accounts_bp.route('/meta/customers', methods=['GET'])
def list_customers():
    customers = execute_query("""
        SELECT customer_id, customer_number, CONCAT(first_name, ' ', last_name) AS full_name, email, customer_tier
        FROM customers
        ORDER BY first_name ASC
    """, fetchall=True)
    return jsonify({"success": True, "customers": customers})

@accounts_bp.route('/meta/branches', methods=['GET'])
def list_branches():
    branches = execute_query("SELECT branch_id, branch_code, branch_name, city, state FROM branches ORDER BY branch_id", fetchall=True)
    return jsonify({"success": True, "branches": branches})

