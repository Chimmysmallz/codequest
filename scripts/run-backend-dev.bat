@echo off
REM Starts the CodeQuest backend in local DEV mode (no Firebase, no Docker).
REM Double-click this file, or run it from a terminal in the project folder.
cd /d "%~dp0..\backend"
if not exist .venv (
  echo Creating Python environment...
  python -m venv .venv
)
call .venv\Scripts\activate
pip install -q -r requirements.txt -r requirements-dev.txt
set AUTH_MODE=insecure_dev
set SANDBOX_MODE=subprocess
echo.
echo Backend starting on http://localhost:8000  (Ctrl+C to stop)
echo Open http://localhost:8000/docs in your browser to try it.
uvicorn main:app --reload --host 0.0.0.0 --port 8000
