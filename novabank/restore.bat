@echo off
REM ============================================================================
REM NovaBank - Database Restore (restore.bat)
REM ============================================================================

if exist venv\Scripts\activate.bat (
    call venv\Scripts\activate.bat
)

python database\restore.py %*
pause

