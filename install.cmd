@echo off
REM install.cmd - Native CMD install script for Windows
REM
REM Usage:
REM   install.cmd                              Install to default location
REM   set SKILL_HOME=C:\path\to\dir ^& install.cmd

setlocal EnableDelayedExpansion

set VERSION=1.0.0
set SKILL_NAME=git
set SCRIPT_DIR=%~dp0
set SRC_DIR=%SCRIPT_DIR%skills\git
if "%SKILL_HOME%"=="" set SKILL_HOME=%USERPROFILE%\.claude\skills\git

echo.
echo [git-skill] Git Skill installer v%VERSION%
echo [git-skill] Source: %SRC_DIR%
echo [git-skill] Target: %SKILL_HOME%
echo.

REM Pre-flight: check git
where git >nul 2>&1
if errorlevel 1 (
    echo [error] git is required but not installed.
    exit /b 1
)

if not exist "%SRC_DIR%\SKILL.md" (
    echo [error] Source skill directory not found: %SRC_DIR%
    echo [error] Are you running this from the git-skill repository root?
    exit /b 1
)

REM Existing install
if exist "%SKILL_HOME%" (
    echo [warn] An installation already exists at %SKILL_HOME%
    set /p CHOICE="Choose: [u]pgrade / [r]einstall / [c]ancel: "
    if /i "!CHOICE!"=="u" goto :copy
    if /i "!CHOICE!"=="r" (
        move "%SKILL_HOME%" "%SKILL_HOME%.bak.%RANDOM%"
        echo [ok] Backed up existing install
        goto :copy
    )
    echo [error] Cancelled
    exit /b 0
)

:copy
if not exist "%SKILL_HOME%" mkdir "%SKILL_HOME%"
xcopy /e /i /y /q "%SRC_DIR%" "%SKILL_HOME%\" >nul
echo [ok] Copied skill to %SKILL_HOME%

REM Done
echo.
echo [ok] Installation complete!
echo.
echo Next steps:
echo   1. Restart Claude Code (or run /reload-skills if available)
echo   2. Try:  /git help
echo   3. Auth: gh auth login / gitee auth login
echo.
echo Uninstall: %SCRIPT_DIR%uninstall.cmd
echo.

endlocal
exit /b 0