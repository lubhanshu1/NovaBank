@echo off
REM ============================================================================
REM NovaBank - Database Backup (backup.bat)
REM ============================================================================

if exist venv\Scripts\activate.bat (
    call venv\Scripts\activate.bat
)

python database\backup.py
pause

