#!/usr/bin/env python3
"""
NovaBank - Database Backup Utility
Dumps the database to a dated SQL backup file in the backups/ directory.
Supports mysqldump with seamless cross-platform execution.
"""

import os
import sys
import subprocess
from datetime import datetime
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env'))

DB_HOST = os.getenv('DB_HOST', '127.0.0.1')
DB_PORT = os.getenv('DB_PORT', '3306')
DB_USER = os.getenv('DB_USER', 'root')
DB_PASSWORD = os.getenv('DB_PASSWORD', '')
DB_NAME = os.getenv('DB_NAME', 'novabank')

BACKUP_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'backups')
os.makedirs(BACKUP_DIR, exist_ok=True)

def run_backup():
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_file = os.path.join(BACKUP_DIR, f"novabank_backup_{timestamp}.sql")
    
    print(f"Creating backup for '{DB_NAME}' at: {backup_file}")
    
    # Check if mysqldump is available
    cmd = [
        "mysqldump",
        f"-h{DB_HOST}",
        f"-P{DB_PORT}",
        f"-u{DB_USER}",
        "--routines",
        "--triggers",
        "--set-gtid-purged=OFF",
        "--single-transaction",
        DB_NAME
    ]
    if DB_PASSWORD:
        cmd.insert(4, f"-p{DB_PASSWORD}")

    try:
        with open(backup_file, "w", encoding="utf-8") as out:
            res = subprocess.run(cmd, stdout=out, stderr=subprocess.PIPE, text=True)
            if res.returncode == 0:
                print(f"Backup created successfully: {os.path.basename(backup_file)} ({os.path.getsize(backup_file)} bytes)")
                return True
            else:
                print(f"mysqldump error: {res.stderr}")
                return False
    except FileNotFoundError:
        print("mysqldump utility not found on PATH. Please ensure MySQL bin directory is on PATH.")
        return False
    except Exception as e:
        print(f"Backup failed: {e}")
        return False

if __name__ == '__main__':
    success = run_backup()
    sys.exit(0 if success else 1)
