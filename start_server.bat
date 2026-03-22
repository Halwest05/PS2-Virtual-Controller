@echo off
title PS2 Virtual Controller Server
echo Starting the PS2 Virtual Controller Server...
echo ===========================================
echo Once started, open your phone browser and go to:
echo http://192.168.100.157
echo ===========================================
cd host
..\venv\Scripts\uvicorn.exe main:app --host 0.0.0.0 --port 80
pause
