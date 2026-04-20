@echo off
REM Claude Desktop Launcher -- verifies config symlinks are intact
REM before starting Claude Desktop. Pin this to the taskbar instead
REM of Claude Desktop directly.
REM
REM Why: Claude Desktop updates use atomic writes that replace the
REM claude_desktop_config.json symlink with a regular file, silently
REM breaking the MCP gateway connection and all alwaysAllow rules.
REM Running the verify script before every launch makes this self-healing.

setlocal

REM Prefer the Git Bash that ships with Git for Windows.
set "BASH_EXE=C:\Program Files\Git\bin\bash.exe"
if not exist "%BASH_EXE%" set "BASH_EXE=bash.exe"

set "VERIFY_SCRIPT=C:\dev\claude-skills-suite\scripts\verify-symlinks.sh"

if exist "%VERIFY_SCRIPT%" (
    "%BASH_EXE%" "%VERIFY_SCRIPT%"
) else (
    echo [launcher] verify-symlinks.sh not found at %VERIFY_SCRIPT%
)

REM Launch Claude Desktop via its Store app identifier.
REM PackageFamilyName: Claude_pzs8sxrjxfjjc   AppId: Claude
start "" "shell:AppsFolder\Claude_pzs8sxrjxfjjc!Claude"

endlocal
exit /b 0
