from flask import Blueprint, request, jsonify, session
from ..db import execute_query, call_procedure

loans_bp = Blueprint('loans', __name__, url_prefix='/api/loans')

@loans_bp.route('', methods=['GET'])
def list_loans():
    cust_id = request.args.get('customer_id')
    role = session.get('role')
    user_cust_id = session.get('customer_id')

    if role == 'CUSTOMER' and user_cust_id:
        cust_id = user_cust_id

    sql = """
        SELECT 
            l.loan_id,
            l.loan_number,
            l.loan_type,
            l.principal_amount,
            l.interest_rate,
            l.term_months,
            l.monthly_emi,
            l.outstanding_balance,
            l.status,
            l.start_date,
            l.end_date,
            c.customer_number,
            CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
            c.email AS customer_email,
            a.account_number
        FROM loans l
        JOIN customers c ON l.customer_id = c.customer_id
        JOIN accounts a ON l.account_id = a.account_id
    """
    params = []
    if cust_id:
        sql += " WHERE l.customer_id = %s"
        params.append(cust_id)

    sql += " ORDER BY l.created_at DESC"

    loans = execute_query(sql, params, fetchall=True)
    return jsonify({"success": True, "count": len(loans), "loans": loans})

@loans_bp.route('/<int:loan_id>/payments', methods=['GET'])
def get_loan_payments(loan_id):
    payments = execute_query("""
        SELECT payment_id, payment_number, payment_amount, principal_component,
               interest_component, payment_date, status
        FROM loan_payments
        WHERE loan_id = %s
        ORDER BY payment_number ASC
    """, (loan_id,), fetchall=True)
    return jsonify({"success": True, "payments": payments})

@loans_bp.route('/apply', methods=['POST'])
def apply_loan():
    """
    Applies for a loan through the transactional application service.
    Computes EMI mathematically and disburses funds into customer's account.
    """
    data = request.get_json() or {}
    customer_id = data.get('customer_id')
    account_id = data.get('account_id')
    loan_type = data.get('loan_type', 'PERSONAL').upper()
    principal = float(data.get('principal_amount', 10000))
    term_months = int(data.get('term_months', 24))
    interest_rate = float(data.get('interest_rate', 7.5))

    if not customer_id or not account_id or principal <= 0 or term_months <= 0:
        return jsonify({"success": False, "message": "All loan application fields are required"}), 400

    # sp_apply_loan signature:
    # (IN customer_id, IN account_id, IN loan_type, IN principal, IN term_months, IN interest_rate,
    #  OUT loan_id, OUT monthly_emi, OUT status, OUT message)
    res = call_procedure('sp_apply_loan', [
        customer_id, account_id, loan_type, principal, term_months, interest_rate,
        None, None, None, None
    ])

    out = res['out_args']
    loan_id = out[6]
    monthly_emi = out[7]
    status = out[8]
    message = out[9]

    if status == 'SUCCESS':
        return jsonify({
            "success": True,
            "status": status,
            "message": message,
            "loan_id": loan_id,
            "monthly_emi": monthly_emi,
            "procedure_used": "sp_apply_loan"
        }), 201
    else:
        return jsonify({"success": False, "message": message}), 400

@loans_bp.route('/<int:loan_id>/pay', methods=['POST'])
def pay_installment(loan_id):
    """
    Processes an EMI installment through the transactional application service.
    Splits payment into principal and interest components in MySQL.
    """
    data = request.get_json() or {}
    from_acc_no = data.get('account_number')

    if not from_acc_no:
        return jsonify({"success": False, "message": "Account number is required"}), 400

    # sp_pay_loan_installment signature:
    # (IN loan_id, IN from_acc_no, OUT status, OUT message)
    res = call_procedure('sp_pay_loan_installment', [
        loan_id, from_acc_no, None, None
    ])

    out = res['out_args']
    status = out[2]
    message = out[3]

    if status == 'SUCCESS':
        return jsonify({
            "success": True,
            "status": status,
            "message": message,
            "procedure_used": "sp_pay_loan_installment"
        })
    return jsonify({"success": False, "message": message}), 400

