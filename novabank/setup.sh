#!/usr/bin/env bash
# ============================================================================
# NovaBank - Setup Script (macOS / Linux)
# ============================================================================

set -e

echo "================================================================="
echo "        NovaBank Core Banking & DBMS Lab - Setup Environment    "
echo "================================================================="

# 1. Check Python version
if ! command -v python3 &> /dev/null; then
    echo "[!] Error: python3 is not installed or not in PATH."
    exit 1
fi
echo "[+] Found Python: $(python3 --version)"

# 2. Check MySQL
if command -v mysql &> /dev/null; then
    echo "[+] Found MySQL CLI: $(mysql --version)"
else
    echo "[*] Notice: mysql CLI not found on PATH, Python connector will be used."
fi

# 3. Environment file check
if [ ! -f .env ]; then
    echo "[+] Creating .env configuration from .env.example..."
    cp .env.example .env
else
    echo "[+] Using existing .env configuration."
fi

# 4. Virtual Environment
if [ ! -d "venv" ]; then
    echo "[+] Creating Python virtual environment in ./venv..."
    python3 -m venv venv
else
    echo "[+] Using existing virtual environment in ./venv."
fi

echo "[+] Activating virtual environment..."
source venv/bin/activate

# 5. Upgrade pip and install requirements
echo "[+] Installing required Python packages..."
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
echo "[+] Dependencies installed successfully."

# 6. Initialize & Seed Database
echo "[+] Installing TiDB-compatible schema, views & seed data..."
python3 setup_tidb.py

# 7. Run Verification Test Suite
echo "[+] Running automated test verification..."
python3 -m unittest backend/test_backend.py

echo "================================================================="
echo "[SUCCESS] NovaBank setup completed successfully!"
echo "Run './run.sh' to start the application and access http://127.0.0.1:5000"
echo "================================================================="

