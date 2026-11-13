@echo off
REM ============================================================================
REM NovaBank - Windows Setup Script (setup.bat)
REM ============================================================================

echo =================================================================
echo         NovaBank Core Banking & DBMS Lab - Windows Setup         
echo =================================================================

REM 1. Check Python
python --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [!] Python is not installed or not in PATH. Please install Python 3.10+ from python.org.
    pause
    exit /b 1
)

echo [+] Python found.

REM 2. Environment file check
if not exist .env (
    echo [+] Creating .env configuration from .env.example...
    copy .env.example .env >nul
) else (
    echo [+] Using existing .env configuration.
)

REM 3. Create virtual environment
if not exist venv (
    echo [+] Creating Python virtual environment in .\venv...
    python -m venv venv
) else (
    echo [+] Virtual environment already exists.
)

echo [+] Activating virtual environment...
call venv\Scripts\activate.bat

REM 4. Install dependencies
echo [+] Installing requirements...
python -m pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
echo [+] Dependencies installed successfully.

REM 5. Initialize & Seed Database
echo [+] Installing TiDB-compatible schema, views and seed data...
python setup_tidb.py
if %ERRORLEVEL% neq 0 (
    echo [!] Database initialization failed. Please verify TiDB credentials in .env.
    pause
    exit /b 1
)

REM 6. Run verification tests
echo [+] Running verification test suite...
python -m unittest backend\test_backend.py

echo =================================================================
echo [SUCCESS] NovaBank setup completed successfully!
echo Run 'run.bat' to start the application and open the dashboard.
echo =================================================================
pause

