@echo off
REM ============================================================================
REM NovaBank - Windows Application Runner (run.bat)
REM Activates venv, verifies database connection, displays logs, and launches app.
REM ============================================================================

echo =================================================================
echo                 NovaBank - Windows Launcher                      
echo =================================================================

if not exist venv (
    echo [!] Virtual environment not detected. Running setup.bat first...
    call setup.bat
)

call venv\Scripts\activate.bat

echo [*] Verifying TiDB database connectivity...
python -c "from backend.db import check_connection; from backend.config import Config; print('================================================================='); print(f'[*] Target Server:     {Config.DB_HOST}:{Config.DB_PORT}'); print(f'[*] Database Schema:   {Config.DB_NAME}'); print(f'[*] Connecting As:     {Config.DB_USER}'); status = check_connection(); print('[+] [SUCCESS] Connected to database!' if status.get('connected') else f'[!] [FAILED] {status.get(\"error\")}'); print(f'    * Database Version:   {status.get(\"version\")}') if status.get('connected') else None; print(f'    * Objects Found:   {status.get(\"total_tables\")} tables & views') if status.get('connected') else None; print('=================================================================')"

REM Launch default browser after 2 seconds
start "" http://127.0.0.1:5000

echo [*] Application running at: http://127.0.0.1:5000
echo [*] Streaming logs below (Press Ctrl+C to stop):
echo -----------------------------------------------------------------

python -m backend.app
pause

