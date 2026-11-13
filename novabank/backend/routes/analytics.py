from flask import Blueprint, jsonify
from ..db import execute_query

analytics_bp = Blueprint('analytics', __name__, url_prefix='/api/analytics')

@analytics_bp.route('/summary', methods=['GET'])
def get_summary():
    """Reads system totals and metrics aggregated from MySQL views."""
    totals = execute_query("""
        SELECT 
            (SELECT COUNT(*) FROM customers) AS total_customers,
            (SELECT COUNT(*) FROM accounts WHERE status = 'ACTIVE') AS total_active_accounts,
            (SELECT COALESCE(SUM(balance), 0) FROM accounts WHERE status = 'ACTIVE') AS total_deposits,
            (SELECT COUNT(*) FROM transactions) AS total_transactions,
            (SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE status = 'COMPLETED') AS total_volume_settled,
            (SELECT COUNT(*) FROM loans WHERE status = 'ACTIVE') AS active_loans,
            (SELECT COALESCE(SUM(outstanding_balance), 0) FROM loans WHERE status = 'ACTIVE') AS total_loan_book
    """, fetchone=True)

    # Top customers by balance from view
    top_customers = execute_query("""
        SELECT customer_number, full_name, customer_tier, total_accounts, total_active_balance, primary_branch
        FROM vw_customer_account_summary
        ORDER BY total_active_balance DESC
        LIMIT 5
    """, fetchall=True)

    return jsonify({
        "success": True,
        "metrics": totals,
        "top_customers": top_customers
    })

@analytics_bp.route('/daily-metrics', methods=['GET'])
def get_daily_metrics():
    """Reads time-series transaction metrics from view vw_daily_transaction_metrics."""
    data = execute_query("""
        SELECT txn_date, transaction_type, channel, transaction_count, total_volume, average_amount
        FROM vw_daily_transaction_metrics
        ORDER BY txn_date ASC
    """, fetchall=True)
    return jsonify({"success": True, "daily_metrics": data})

@analytics_bp.route('/high-risk', methods=['GET'])
def get_high_risk():
    """Reads compliance audit alerts from view vw_high_risk_transactions."""
    alerts = execute_query("""
        SELECT transaction_id, reference_no, transaction_date, transaction_type,
               amount, status, channel, account_number, account_holder,
               customer_tier, risk_classification
        FROM vw_high_risk_transactions
        ORDER BY transaction_date DESC
        LIMIT 25
    """, fetchall=True)
    return jsonify({"success": True, "alerts": alerts})

@analytics_bp.route('/loan-health', methods=['GET'])
def get_loan_health():
    """Reads loan portfolio distribution from view vw_loan_portfolio_health."""
    portfolio = execute_query("""
        SELECT loan_type, total_loans, active_loans, paid_off_loans,
               total_principal_disbursed, total_outstanding_balance,
               avg_interest_rate, total_monthly_expected_inflow
        FROM vw_loan_portfolio_health
    """, fetchall=True)
    return jsonify({"success": True, "portfolio": portfolio})

@analytics_bp.route('/branch-performance', methods=['GET'])
def get_branch_performance():
    """Reads branch operational statistics from view vw_branch_performance."""
    branches = execute_query("""
        SELECT branch_id, branch_code, branch_name, city, state,
               total_customers, total_accounts, total_deposits, total_loans_issued
        FROM vw_branch_performance
        ORDER BY total_deposits DESC
    """, fetchall=True)
    return jsonify({"success": True, "branches": branches})

