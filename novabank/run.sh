#!/usr/bin/env bash
# ============================================================================
# NovaBank - Application Runner (macOS / Linux)
# Starts backend and serves frontend while streaming connection logs.
# ============================================================================

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "================================================================="
echo "               NovaBank - Starting Application                   "
echo "================================================================="

# Check virtual environment
if [ ! -d "venv" ]; then
    echo "[!] Virtual environment not found. Running ./setup.sh first..."
    ./setup.sh
fi

source venv/bin/activate

# Connectivity Verification & Terminal Logs
echo "[*] Verifying database connectivity..."
python3 -c "
from backend.db import check_connection
from backend.config import Config

print('=================================================================')
print(f'[*] Target Host:       {Config.DB_HOST}:{Config.DB_PORT}')
print(f'[*] Database Schema:   {Config.DB_NAME}')
print(f'[*] User Account:      {Config.DB_USER}')
status = check_connection()
if status.get('connected'):
    print('[+] [SUCCESS] Database is CONNECTED!')
    print(f'    * MySQL Version:   {status.get(\"version\")}')
    print(f'    * Schema Objects:  {status.get(\"total_tables\")} tables & views')
    print(f'    * Active User:     {status.get(\"user\")}')
    print(f'    * Server Time:     {status.get(\"server_time\")}')
else:
    print('[!] [ERROR] Database is NOT connected!')
    print(f'    * Detail: {status.get(\"error\")}')
    print('[!] Please check if MySQL server is running.')
print('=================================================================')
"

# Determine port
PORT=$(python3 -c "
import socket
for p in [5000, 5050, 8080]:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('127.0.0.1', p))
            print(p)
            break
    except OSError:
        pass
")
if [ -z "$PORT" ]; then
    PORT=5050
fi

# Open Browser in background if on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    (sleep 1.5 && open "http://127.0.0.1:$PORT") &
fi

echo "[*] NovaBank Dashboard & DBMS Lab is live at: http://127.0.0.1:$PORT"
echo "[*] Streaming application logs (Press Ctrl+C to terminate):"
echo "-----------------------------------------------------------------"

# Start Flask Application
python3 -m backend.app
