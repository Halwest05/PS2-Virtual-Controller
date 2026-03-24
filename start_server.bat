@echo off
title PS2 Virtual Controller Server
echo Starting the PS2 Virtual Controller Server...
echo ===========================================
cd host
..\venv\Scripts\python.exe main.py
pause
