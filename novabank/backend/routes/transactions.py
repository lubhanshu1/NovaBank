from flask import Blueprint, request, jsonify, session
from ..db import execute_query, call_procedure

transactions_bp = Blueprint('transactions', __name__, url_prefix='/api/transactions')

@transactions_bp.route('', methods=['GET'])
def list_transactions():
    account_number = request.args.get('account_number')
    txn_type = request.args.get('type')
    channel = request.args.get('channel')
    limit = int(request.args.get('limit', 50))

    role = session.get('role')
    user_cust_id = session.get('customer_id')

    sql = """
        SELECT 
            t.transaction_id,
            t.reference_no,
            t.transaction_type,
            t.amount,
            t.balance_before,
            t.balance_after,
            t.status,
            t.channel,
            t.description,
            t.transaction_date,
            a.account_number,
            a.account_type,
            CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
            rel_a.account_number AS related_account_number
        FROM transactions t
        JOIN accounts a ON t.account_id = a.account_id
        JOIN customers c ON a.customer_id = c.customer_id
        LEFT JOIN accounts rel_a ON t.related_account_id = rel_a.account_id
        WHERE 1=1
    """
    params = []

    if role == 'CUSTOMER' and user_cust_id:
        sql += " AND a.customer_id = %s"
        params.append(user_cust_id)
    elif account_number:
        sql += " AND a.account_number = %s"
        params.append(account_number)

    if txn_type:
        sql += " AND t.transaction_type = %s"
        params.append(txn_type)

    if channel:
        sql += " AND t.channel = %s"
        params.append(channel)

    sql += " ORDER BY t.transaction_date DESC, t.transaction_id DESC LIMIT %s"
    params.append(limit)

    txns = execute_query(sql, params, fetchall=True)
    return jsonify({"success": True, "count": len(txns), "transactions": txns})

@transactions_bp.route('/transfer', methods=['POST'])
def transfer():
    """
    Executes an atomic fund transfer through the transactional application service.
    All business logic, row locking, and balance integrity checks happen inside MySQL.
    """
    data = request.get_json() or {}
    from_acc = data.get('from_account', '').strip()
    to_acc = data.get('to_account', '').strip()
    amount = float(data.get('amount', 0))
    desc = data.get('description', 'Peer-to-Peer Transfer')
    channel = data.get('channel', 'ONLINE')

    if not from_acc or not to_acc or amount <= 0:
        return jsonify({"success": False, "message": "Source, destination, and positive amount are required."}), 400

    # sp_transfer_funds signature:
    # (p_from_acc, p_to_acc, p_amount, p_description, p_channel, OUT p_status, OUT p_message, OUT p_ref_no)
    res = call_procedure('sp_transfer_funds', [
        from_acc, to_acc, amount, desc, channel,
        None, None, None
    ])

    out = res['out_args']
    status = out[5]
    message = out[6]
    ref_no = out[7]

    if status == 'SUCCESS':
        return jsonify({
            "success": True,
            "status": status,
            "message": message,
            "reference_no": ref_no,
            "procedure": "sp_transfer_funds",
            "database_action": "Atomic 2-Phase Debit & Credit with ROW LOCKING (InnoDB FOR UPDATE)"
        })
    else:
        return jsonify({
            "success": False,
            "status": status,
            "message": message,
            "procedure": "sp_transfer_funds"
        }), 400

@transactions_bp.route('/deposit', methods=['POST'])
def deposit():
    """Executes a deposit through the transactional application service."""
    data = request.get_json() or {}
    acc_no = data.get('account_number', '').strip()
    amount = float(data.get('amount', 0))
    desc = data.get('description', 'Cash Deposit')
    channel = data.get('channel', 'BRANCH')

    if not acc_no or amount <= 0:
        return jsonify({"success": False, "message": "Valid account number and positive amount required."}), 400

    # sp_deposit_funds signature:
    # (p_account_no, p_amount, p_description, p_channel, OUT p_status, OUT p_message, OUT p_ref_no)
    res = call_procedure('sp_deposit_funds', [
        acc_no, amount, desc, channel, None, None, None
    ])

    out = res['out_args']
    status = out[4]
    message = out[5]
    ref_no = out[6]

    if status == 'SUCCESS':
        return jsonify({"success": True, "status": status, "message": message, "reference_no": ref_no})
    return jsonify({"success": False, "status": status, "message": message}), 400

@transactions_bp.route('/withdraw', methods=['POST'])
def withdraw():
    """Executes a withdrawal through the transactional application service."""
    data = request.get_json() or {}
    acc_no = data.get('account_number', '').strip()
    amount = float(data.get('amount', 0))
    desc = data.get('description', 'ATM Cash Withdrawal')
    channel = data.get('channel', 'ATM')

    if not acc_no or amount <= 0:
        return jsonify({"success": False, "message": "Valid account number and positive amount required."}), 400

    res = call_procedure('sp_withdraw_funds', [
        acc_no, amount, desc, channel, None, None, None
    ])

    out = res['out_args']
    status = out[4]
    message = out[5]
    ref_no = out[6]

    if status == 'SUCCESS':
        return jsonify({"success": True, "status": status, "message": message, "reference_no": ref_no})
    return jsonify({"success": False, "status": status, "message": message}), 400

@transactions_bp.route('/beneficiaries', methods=['GET', 'POST'])
def handle_beneficiaries():
    cust_id = session.get('customer_id') or request.args.get('customer_id') or 1

    if request.method == 'GET':
        beneficiaries = execute_query("""
            SELECT beneficiary_id, beneficiary_name, account_number, bank_name, routing_code, nickname
            FROM beneficiaries
            WHERE customer_id = %s
            ORDER BY beneficiary_name ASC
        """, (cust_id,), fetchall=True)
        return jsonify({"success": True, "beneficiaries": beneficiaries})

    data = request.get_json() or {}
    name = data.get('beneficiary_name')
    acc_num = data.get('account_number')
    bank = data.get('bank_name', 'NovaBank')
    routing = data.get('routing_code', 'NVB0001')
    nick = data.get('nickname')

    if not name or not acc_num:
        return jsonify({"success": False, "message": "Name and account number required"}), 400

    execute_query("""
        INSERT INTO beneficiaries (customer_id, beneficiary_name, account_number, bank_name, routing_code, nickname)
        VALUES (%s, %s, %s, %s, %s, %s)
    """, (cust_id, name, acc_num, bank, routing, nick), commit=True)

    return jsonify({"success": True, "message": f"Beneficiary {name} added successfully."}), 201

