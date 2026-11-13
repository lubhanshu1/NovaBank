#!/usr/bin/env bash
# ============================================================================
# NovaBank - Database Backup (macOS / Linux)
# ============================================================================

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

if [ -d "venv" ]; then
    source venv/bin/activate
fi

python3 database/backup.py

