from flask import Blueprint, request, jsonify
from ..db import execute_query

audit_bp = Blueprint('audit', __name__, url_prefix='/api/audit')

@audit_bp.route('/logs', methods=['GET'])
def get_audit_logs():
    table_name = request.args.get('table')
    operation = request.args.get('operation')
    limit = int(request.args.get('limit', 50))

    sql = """
        SELECT audit_id, table_name, operation, record_id, action_summary,
               changed_by, old_values, new_values, timestamp
        FROM audit_logs
        WHERE 1=1
    """
    params = []

    if table_name:
        sql += " AND table_name = %s"
        params.append(table_name)

    if operation:
        sql += " AND operation = %s"
        params.append(operation)

    sql += " ORDER BY timestamp DESC, audit_id DESC LIMIT %s"
    params.append(limit)

    logs = execute_query(sql, params, fetchall=True)

    stats = execute_query("""
        SELECT 
            COUNT(*) AS total_logs,
            SUM(CASE WHEN operation = 'INSERT' THEN 1 ELSE 0 END) AS total_inserts,
            SUM(CASE WHEN operation = 'UPDATE' THEN 1 ELSE 0 END) AS total_updates,
            SUM(CASE WHEN operation = 'DELETE' THEN 1 ELSE 0 END) AS total_deletes
        FROM audit_logs
    """, fetchone=True)

    return jsonify({
        "success": True,
        "stats": stats,
        "count": len(logs),
        "logs": logs
    })

