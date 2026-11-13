@echo off
REM ============================================================================
REM NovaBank - Reset & Reseed Database (reset_db.bat)
REM ============================================================================

if exist venv\Scripts\activate.bat (
    call venv\Scripts\activate.bat
)

python database\reset_db.py
pause

