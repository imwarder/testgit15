@echo off
:: Claude CLI Git Sistemi - PowerShell Launcher
chcp 65001 >nul 2>&1
title Claude CLI Git Sistemi - Kurulum
color 0A

echo.
echo ================================================================================
echo                    CLAUDE CLI GIT SISTEMI KURULUMU
echo ================================================================================
echo.
echo PowerShell script baslatiliyor...
echo.

:: Git kontrolu
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo HATA: Git yuklu degil!
    echo.
    echo Git'i yuklemek icin: https://git-scm.com/download/win
    echo.
    pause
    exit /b 1
)

:: PowerShell kontrolu
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo HATA: PowerShell bulunamadi!
    echo.
    pause
    exit /b 1
)

:: PowerShell Execution Policy ayari
echo PowerShell ayarlari yapiliyor...
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force" >nul 2>&1

:: START.ps1'i calistir
echo START.ps1 baslatiliyor...
powershell -ExecutionPolicy Bypass -File "START.ps1"

if %errorlevel% neq 0 (
    echo.
    echo HATA: START.ps1 calistirilirken hata olustu!
    pause
    exit /b 1
)

echo.
echo START.ps1 basariyla tamamlandi!
pause