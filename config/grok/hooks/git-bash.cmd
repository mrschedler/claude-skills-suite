@echo off
REM Grok hook launcher. Grok resolves bare "bash" to C:\Windows\System32\bash.exe
REM (WSL), which has no distro /bin/bash here and spam-fails every hook.
REM Claude Code already forces Git Bash; Grok does not. Keep this file next to
REM grok-hooks.json and invoke scripts through it.
"C:\Program Files\Git\bin\bash.exe" %*
