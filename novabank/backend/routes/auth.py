from flask import Blueprint, request, jsonify, session
from werkzeug.security import check_password_hash, generate_password_hash
from ..db import execute_query

auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json() or {}
    username = data.get('username', '').strip()
    password = data.get('password', '')

    if not username or not password:
        return jsonify({"success": False, "message": "Username and password required"}), 400

    user = execute_query(
        "SELECT user_id, username, password_hash, role, customer_id, is_active FROM users WHERE username = %s",
        (username,),
        fetchone=True
    )

    if not user:
        return jsonify({"success": False, "message": "Invalid username or password"}), 401

    if not user.get('is_active'):
        return jsonify({"success": False, "message": "Account is disabled. Contact bank administrator."}), 403

    if not check_password_hash(user['password_hash'], password):
        return jsonify({"success": False, "message": "Invalid username or password"}), 401

    # Update last login
    execute_query(
        "UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE user_id = %s",
        (user['user_id'],),
        commit=True
    )

    customer_info = None
    if user.get('customer_id'):
        customer_info = execute_query(
            "SELECT customer_id, customer_number, first_name, last_name, email, customer_tier FROM customers WHERE customer_id = %s",
            (user['customer_id'],),
            fetchone=True
        )

    # Set session
    session['user_id'] = user['user_id']
    session['username'] = user['username']
    session['role'] = user['role']
    session['customer_id'] = user['customer_id']

    return jsonify({
        "success": True,
        "message": f"Welcome back, {user['username']}!",
        "user": {
            "user_id": user['user_id'],
            "username": user['username'],
            "role": user['role'],
            "customer_id": user['customer_id'],
            "customer": customer_info
        }
    })

@auth_bp.route('/me', methods=['GET'])
def me():
    user_id = session.get('user_id')
    if not user_id:
        # For seamless demo testing, return default demo admin if not explicitly logged in
        return jsonify({
            "authenticated": False,
            "demo_users": [
                {"username": "admin", "role": "ADMIN", "description": "Full System Administrator"},
                {"username": "teller1", "role": "TELLER", "description": "Branch Teller / Cashier"},
                {"username": "auditor1", "role": "AUDITOR", "description": "Compliance & Audit Inspector"},
                {"username": "kush", "role": "CUSTOMER", "description": "VIP Banking Customer (Kush Dalal)"},
                {"username": "priya", "role": "CUSTOMER", "description": "Premium Customer (Priya Sharma)"}
            ]
        })

    user = execute_query(
        "SELECT user_id, username, role, customer_id FROM users WHERE user_id = %s",
        (user_id,),
        fetchone=True
    )
    return jsonify({"authenticated": True, "user": user})

@auth_bp.route('/logout', methods=['POST'])
def logout():
    session.clear()
    return jsonify({"success": True, "message": "Logged out successfully"})

@auth_bp.route('/demo-switch', methods=['POST'])
def demo_switch():
    """Allows rapid role switching in the UI to evaluate different user perspectives."""
    data = request.get_json() or {}
    target_username = data.get('username')

    user = execute_query(
        "SELECT user_id, username, role, customer_id FROM users WHERE username = %s",
        (target_username,),
        fetchone=True
    )
    if not user:
        return jsonify({"success": False, "message": "Demo user not found"}), 404

    customer_info = None
    if user.get('customer_id'):
        customer_info = execute_query(
            "SELECT customer_id, customer_number, first_name, last_name, email, customer_tier FROM customers WHERE customer_id = %s",
            (user['customer_id'],),
            fetchone=True
        )

    session['user_id'] = user['user_id']
    session['username'] = user['username']
    session['role'] = user['role']
    session['customer_id'] = user['customer_id']

    return jsonify({
        "success": True,
        "message": f"Switched active persona to {user['username']} ({user['role']})",
        "user": {
            "user_id": user['user_id'],
            "username": user['username'],
            "role": user['role'],
            "customer_id": user['customer_id'],
            "customer": customer_info
        }
    })

