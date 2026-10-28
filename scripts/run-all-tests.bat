@echo off
REM Runs the backend tests on your own computer (Windows).
cd /d "%~dp0..\backend"
if not exist .venv python -m venv .venv
call .venv\Scripts\activate
pip install -q -r requirements.txt -r requirements-dev.txt
python -m pytest
pause
