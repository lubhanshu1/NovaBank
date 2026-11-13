# NovaBank on TiDB Cloud Starter + Vercel

## Architecture adaptation
TiDB does not support MySQL stored procedures or triggers. The former `sp_*` operations now run in `backend/db.py` as parameterized Python service functions using explicit transactions, row locking, and explicit audit-log writes. Do not execute `03_procedures.sql`, `04_triggers.sql`, or `05_roles_and_security.sql` on TiDB.

## Configure TiDB
1. Reset any password previously exposed in a screenshot.
2. Copy `.env.example` to `.env` locally and set the TiDB host, port 4000, username, new password, database `novabank`, and a strong `SECRET_KEY`.
3. Install dependencies with `pip install -r requirements.txt`.
4. Run `python setup_tidb.py` once to install tables, views and demo data. This changes the database. Use `python setup_tidb.py --reset` only if you intend to drop and rebuild it.

## Vercel
Import the project repository, add the variables from `.env.example` in Project Settings → Environment Variables, and deploy. Never commit `.env`. Check `/api/health`; it should report `database.connected: true`. `api/index.py` is the Flask entry point.

## Notes
This is a student/demo banking application, not production banking software. Do not use real customer data or real money. Free tiers have quotas and may change; monitor usage and configure zero-spend limits where available.

TiDB compatibility: https://docs.pingcap.com/tidbcloud/mysql-compatibility/
