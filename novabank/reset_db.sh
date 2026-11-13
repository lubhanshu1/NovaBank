#!/usr/bin/env bash
# ============================================================================
# NovaBank - Database Reset & Reseed (macOS / Linux)
# ============================================================================

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

if [ -d "venv" ]; then
    source venv/bin/activate
fi

python3 database/reset_db.py

