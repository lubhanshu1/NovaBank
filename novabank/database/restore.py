#!/usr/bin/env python3
"""
NovaBank - Database Restore Utility
Restores the database from a specified SQL backup file or the latest backup file in backups/.
"""

import os
import sys
import glob
import subprocess
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env'))

DB_HOST = os.getenv('DB_HOST', '127.0.0.1')
DB_PORT = os.getenv('DB_PORT', '3306')
DB_USER = os.getenv('DB_USER', 'root')
DB_PASSWORD = os.getenv('DB_PASSWORD', '')
DB_NAME = os.getenv('DB_NAME', 'novabank')

BACKUP_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'backups')

def run_restore(backup_file=None):
    if not backup_file:
        files = sorted(glob.glob(os.path.join(BACKUP_DIR, "novabank_backup_*.sql")))
        if not files:
            print(f"No backup files found in {BACKUP_DIR}")
            return False
        backup_file = files[-1]  # Latest

    if not os.path.exists(backup_file):
        print(f"Backup file not found: {backup_file}")
        return False

    print(f"Restoring database '{DB_NAME}' from: {backup_file}")

    cmd = [
        "mysql",
        f"-h{DB_HOST}",
        f"-P{DB_PORT}",
        f"-u{DB_USER}",
        DB_NAME
    ]
    if DB_PASSWORD:
        cmd.insert(4, f"-p{DB_PASSWORD}")

    try:
        with open(backup_file, "r", encoding="utf-8") as inp:
            res = subprocess.run(cmd, stdin=inp, stderr=subprocess.PIPE, text=True)
            if res.returncode == 0:
                print(f"Database restored successfully from {os.path.basename(backup_file)}.")
                return True
            else:
                print(f"mysql restore error: {res.stderr}")
                return False
    except Exception as e:
        print(f"Restore failed: {e}")
        return False

if __name__ == '__main__':
    target = sys.argv[1] if len(sys.argv) > 1 else None
    success = run_restore(target)
    sys.exit(0 if success else 1)

