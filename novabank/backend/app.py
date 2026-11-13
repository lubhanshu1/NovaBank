import os
import sys
from flask import Flask, send_from_directory, jsonify, request
from flask_cors import CORS
from .config import Config
from .db import init_pool, check_connection
from .routes.auth import auth_bp
from .routes.accounts import accounts_bp
from .routes.transactions import transactions_bp
from .routes.loans import loans_bp
from .routes.analytics import analytics_bp
from .routes.audit import audit_bp
from .routes.dbms_lab import lab_bp

FRONTEND_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'frontend')

def create_app():
    app = Flask(
        __name__,
        static_folder=FRONTEND_DIR,
        static_url_path=''
    )
    
    app.config.from_object(Config)
    CORS(app, supports_credentials=True)

    # Register Blueprints
    app.register_blueprint(auth_bp)
    app.register_blueprint(accounts_bp)
    app.register_blueprint(transactions_bp)
    app.register_blueprint(loans_bp)
    app.register_blueprint(analytics_bp)
    app.register_blueprint(audit_bp)
    app.register_blueprint(lab_bp)

    # Static Frontend Routes
    @app.route('/')
    def serve_index():
        return send_from_directory(FRONTEND_DIR, 'index.html')

    @app.route('/<path:path>')
    def serve_static(path):
        full_path = os.path.join(FRONTEND_DIR, path)
        if os.path.exists(full_path):
            return send_from_directory(FRONTEND_DIR, path)
        return send_from_directory(FRONTEND_DIR, 'index.html')

    # Health Check API
    @app.route('/api/health', methods=['GET'])
    def health():
        db_status = check_connection()
        return jsonify({
            "status": "online" if db_status.get("connected") else "degraded",
            "app": "NovaBank Core Banking & DBMS Lab",
            "database": {k: v for k, v in db_status.items() if k not in ("user",)}
        })

    # Error Handlers
    @app.errorhandler(404)
    def not_found(e):
        if request.path.startswith('/api/'):
            return jsonify({"success": False, "message": "API endpoint not found"}), 404
        return send_from_directory(FRONTEND_DIR, 'index.html')

    @app.errorhandler(500)
    def internal_error(e):
        return jsonify({"success": False, "message": "Internal Server Error", "detail": str(e)}), 500

    return app

def find_available_port(preferred_port=5000):
    import socket
    for port in [preferred_port, 5050, 8080, 5005]:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('127.0.0.1', port))
                return port
        except OSError:
            continue
    return preferred_port

def main():
    print("=" * 65)
    print("        NovaBank - Banking Management System & DBMS Lab")
    print("=" * 65)
    print(f"[*] Target Database Server: {Config.DB_HOST}:{Config.DB_PORT}")
    print(f"[*] Database Name:          {Config.DB_NAME}")
    print(f"[*] Connecting as User:     {Config.DB_USER}")
    
    # Initialize connection pool and test connectivity
    pool_ok = init_pool()
    db_status = check_connection()
    
    if db_status.get('connected'):
        print("[+] [SUCCESS] Connected to MySQL Database!")
        print(f"    - MySQL Version:       {db_status.get('version')}")
        print(f"    - Active Schema:       {db_status.get('database')}")
        print(f"    - Authenticated User:  {db_status.get('user')}")
        print(f"    - Database Tables:     {db_status.get('total_tables')}")
        print(f"    - Server Timestamp:    {db_status.get('server_time')}")
    else:
        print("[!] [WARNING] Database Connection Failed!")
        print(f"    - Error Detail: {db_status.get('error')}")
        print("    - Please verify MySQL service is running and .env credentials are correct.")

    port = find_available_port(Config.PORT)
    print(f"[*] Serving Modern Web UI from: {FRONTEND_DIR}")
    print(f"[*] NovaBank Application URL:    http://127.0.0.1:{port}")
    print("=" * 65)

    app = create_app()
    app.run(host='0.0.0.0', port=port, debug=Config.DEBUG, use_reloader=False)

if __name__ == '__main__':
    main()
