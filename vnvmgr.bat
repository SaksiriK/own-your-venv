@echo off
rem List, activate, create, or edit Python venvs in this folder.
rem   vnvmgr                       - lists environments, prompts for a selection
rem   vnvmgr <name>                - activates that environment in this cmd session
rem   vnvmgr <name> script.py args - runs script.py under <name>'s python directly
rem                                  (no activation) and forwards its exit code -
rem                                  for invoking a shared env from another script
rem                                  without its own .venv.
rem   vnvmgr new                   - create a new environment
rem   vnvmgr edit <name>           - edit <name>'s comment.txt
rem   vnvmgr, then "i"             - show this reference and the Python-code snippet
rem
rem Venvs (pyvenv.cfg) activate via their own Scripts\activate.bat.
rem "new" and "edit" are reserved command words - an environment folder
rem literally named "new" or "edit" would be shadowed by them.

set "REPO=%~dp0"
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"

rem ANSI color codes - supported by default in cmd.exe on Windows 10/11.
rem Colors mirror vnvmgr.ps1's scheme: Cyan headers, Green success, Red
rem errors, Yellow warnings, Gray for paths/hints. Harmless if a given
rem terminal doesn't render them - they just show as no-ops around the text.
for /F %%a in ('echo prompt $E^|cmd') do set "ESC=%%a"
set "COL_CYAN=%ESC%[36m"
set "COL_GREEN=%ESC%[32m"
set "COL_RED=%ESC%[31m"
set "COL_YELLOW=%ESC%[33m"
set "COL_GRAY=%ESC%[90m"
set "COL_RESET=%ESC%[0m"

if /i "%~1"=="new" goto :createnew
if /i "%~1"=="edit" goto :editcomment_arg

if not "%~2"=="" goto :runmode

setlocal enabledelayedexpansion
rem Discovery/selection below is scoped by setlocal (safe: delayed expansion
rem needs it). Only TARGET/TARGETNAME are carried past "endlocal" so the
rem actual activation runs in the caller's real environment, not a scope
rem that gets discarded when this script ends.

set "count=0"
for /d %%D in ("%REPO%\*") do (
    if exist "%%D\pyvenv.cfg" (
        set /a count+=1
        set "venv!count!=%%~nxD"
        set "venvpath!count!=%%D"
        set "comment!count!="
        if exist "%%D\comment.txt" set /p "comment!count!=" 0<"%%D\comment.txt"
    )
)

if "%count%"=="0" (
    rem Note: no color codes here, deliberately - a colored echo (the ESC
    rem control character expanding via %VAR%) inside a multi-line
    rem parenthesized block can corrupt cmd.exe's block-parsing state,
    rem breaking a later goto's label search elsewhere in the script (hit
    rem this for real with the "Invalid selection" message below - see the
    rem comment there). Keep every echo inside a "( ... )" block plain.
    echo No environments found under %REPO% ^(looked for subfolders containing pyvenv.cfg^).
    echo Run "vnvmgr new" to create one.
    endlocal
    exit /b 1
)

set "TARGET="
set "TARGETNAME="

if not "%~1"=="" (
    for /l %%i in (1,1,%count%) do (
        if /i "!venv%%i!"=="%~1" (
            set "TARGET=!venvpath%%i!"
            set "TARGETNAME=!venv%%i!"
        )
    )
    if not defined TARGET (
        echo No environment named "%~1" found.
        call :listenvs
        endlocal
        exit /b 1
    )
    goto :activate
)

call :listenvs
set /p "choice=%COL_CYAN%Enter number or name to activate, 'new' to create, 'edit ' to edit a comment, 'i' for info (blank to cancel): %COL_RESET%"

:trimchoice
rem set /p occasionally leaves a trailing space (seen with piped input);
rem strip it so comparisons and env-name lookups below match cleanly.
if "!choice:~-1!"==" " (
    set "choice=!choice:~0,-1!"
    goto :trimchoice
)

if "!choice!"=="" (
    endlocal
    exit /b 0
)

if /i "!choice!"=="i" (
    endlocal
    goto :showhelp
)
if /i "!choice!"=="new" (
    endlocal
    goto :createnew
)
if /i "!choice!"=="edit" (
    endlocal
    goto :editcomment_needname
)
if /i "!choice:~0,5!"=="edit " (
    set "EDITNAME=!choice:~5!"
    goto :editcomment_carry
)

echo(!choice!| findstr /r "^[0-9][0-9]*$" >nul
if !errorlevel! equ 0 (
    if !choice! geq 1 if !choice! leq %count% (
        set "TARGET=!venvpath%choice%!"
        set "TARGETNAME=!venv%choice%!"
    )
) else (
    for /l %%i in (1,1,%count%) do (
        if /i "!venv%%i!"=="!choice!" (
            set "TARGET=!venvpath%%i!"
            set "TARGETNAME=!venv%%i!"
        )
    )
)

if not defined TARGET (
    rem No color here - the ESC control character from a colored echo,
    rem expanded via %VAR% inside this parenthesized block, corrupted
    rem cmd.exe's parsing enough that the "goto :activate" a few lines
    rem down (and even gotos elsewhere in the file, like :editcomment_
    rem needname) could no longer find their target labels. Confirmed by
    rem bisection - do not add color back inside this block.
    echo Invalid selection "!choice!".
    endlocal
    exit /b 1
)
goto :activate

:editcomment_carry
rem Same carry-over trick as :activate below - this must be its own
rem standalone line, not nested inside the "if" block that set EDITNAME,
rem or %EDITNAME% would expand to its pre-block (empty) value instead.
endlocal & set "EDITNAME=%EDITNAME%"
goto :editcomment_withname

:activate
rem Carry TARGET/TARGETNAME out of the setlocal scope so the activation's
rem env changes land in the real caller session instead of being discarded.
endlocal & set "TARGET=%TARGET%" & set "TARGETNAME=%TARGETNAME%"

if not exist "%TARGET%\Scripts\activate.bat" (
    echo "%TARGETNAME%" has no Scripts\activate.bat - is it a valid venv?
    exit /b 1
)
call "%TARGET%\Scripts\activate.bat"
echo %COL_GREEN%Activated "%TARGETNAME%"%COL_RESET%
echo %COL_GRAY%  %TARGET%%COL_RESET%
exit /b 0

:listenvs
echo %COL_CYAN%Environments in %REPO%. select an option:%COL_RESET%
for /l %%i in (1,1,%count%) do call :print_one %%i
exit /b 0

:print_one
if defined comment%1 (
    echo   [%1] !venv%1! - !comment%1!
) else (
    echo   [%1] !venv%1!
)
exit /b 0

:showhelp
echo %COL_CYAN%Shared environments in %REPO% - no need to create a project .venv.%COL_RESET%
echo(
echo   vnvmgr                          list environments, choose one to activate
echo   vnvmgr ^<name^>                   activate ^<name^> in this shell session
echo   vnvmgr ^<name^> script.py [args]  run script.py under ^<name^>'s python, no activation
echo   vnvmgr new                      create a new environment
echo   vnvmgr edit ^<name^>              edit ^<name^>'s comment.txt
echo(
echo From Python code, to run something under a shared env:
echo   import subprocess
echo   subprocess.run^([r"%REPO%\<name>\Scripts\python.exe", "script.py", "--arg", "value"]^)
echo(
exit /b 0

:createnew
rem create-venv.ps1 writes %TEMP%\own-your-venv-created.txt on success (it
rem doesn't reliably signal success/failure via exit code otherwise) -
rem clear any stale one first so it can't be mistaken for success here.
if exist "%TEMP%\own-your-venv-created.txt" del "%TEMP%\own-your-venv-created.txt"
call "%~dp0create-venv.bat"
echo(
if exist "%TEMP%\own-your-venv-created.txt" (
    echo Re-run vnvmgr to see the new environment.
    del "%TEMP%\own-your-venv-created.txt"
)
exit /b 0

:editcomment_arg
rem vnvmgr edit <name> - name given directly as %~2
if "%~2"=="" goto :editcomment_needname
set "EDITNAME=%~2"
goto :editcomment_withname

:editcomment_needname
rem Name not given yet - this is self-contained (own setlocal/discovery)
rem since it can be reached before the main discovery block runs at all
rem (direct "vnvmgr edit" from cmd.exe) as well as after it's already
rem ended (interactive "edit" typed at the menu).
setlocal enabledelayedexpansion
set "count=0"
for /d %%D in ("%REPO%\*") do (
    if exist "%%D\pyvenv.cfg" (
        set /a count+=1
        set "venv!count!=%%~nxD"
        set "comment!count!="
        if exist "%%D\comment.txt" set /p "comment!count!=" 0<"%%D\comment.txt"
    )
)
if "%count%"=="0" (
    echo No environments found under %REPO% ^(looked for subfolders containing pyvenv.cfg^).
    endlocal
    exit /b 1
)
echo %COL_CYAN%Environments in %REPO% :%COL_RESET%
for /l %%i in (1,1,%count%) do call :print_one %%i
set /p "editname_in=%COL_CYAN%Environment name to edit the comment for (blank to cancel): %COL_RESET%"

:trim_editname_in
if "!editname_in:~-1!"==" " (
    set "editname_in=!editname_in:~0,-1!"
    goto :trim_editname_in
)
if "!editname_in!"=="" (
    endlocal
    exit /b 0
)

echo(!editname_in!| findstr /r "^[0-9][0-9]*$" >nul
if !errorlevel! equ 0 (
    if !editname_in! geq 1 if !editname_in! leq %count% (
        set "editname_in=!venv%editname_in%!"
    )
)

endlocal & set "EDITNAME=%editname_in%"
goto :editcomment_withname

:editcomment_withname
if not defined EDITNAME (
    echo A name is required.
    exit /b 1
)
if not exist "%REPO%\%EDITNAME%\pyvenv.cfg" (
    echo No environment named "%EDITNAME%" found.
    exit /b 1
)
if exist "%REPO%\%EDITNAME%\comment.txt" (
    echo Current comment:
    type "%REPO%\%EDITNAME%\comment.txt"
    echo(
)
set /p "NEWCOMMENT=%COL_CYAN%New one-line comment for "%EDITNAME%" (replaces the above, blank to cancel): %COL_RESET%"
if "%NEWCOMMENT%"=="" (
    echo No change made.
    exit /b 0
)
rem Written via a PowerShell one-liner rather than "echo %NEWCOMMENT% > file"
rem because a comment containing &, |, <, or > would otherwise be
rem misparsed as batch operators. Passing it through the environment
rem (inherited by the child process) instead of embedding it in the
rem command line sidesteps that entirely.
powershell -NoProfile -Command "Set-Content -NoNewline -Path '%REPO%\%EDITNAME%\comment.txt' -Value $env:NEWCOMMENT"
echo %COL_GREEN%Comment for "%EDITNAME%" updated.%COL_RESET%
exit /b 0

:runmode
rem Direct-run mode: no shell activation, just exec <name>'s python with
rem the remaining arguments and forward its exit code. Self-contained inside
rem its own setlocal since nothing needs to persist afterward.
rem NOTE: SHIFT does not update %*, so the leading (env name) token is
rem stripped from %* directly instead of relying on SHIFT for this.
setlocal
set "ENVNAME=%~1"
set "REST=%*"
call set "REST=%%REST:*%1 =%%"
set "ENVPATH="
for /d %%D in ("%REPO%\*") do (
    if /i "%%~nxD"=="%ENVNAME%" (
        if exist "%%D\pyvenv.cfg" (
            set "ENVPATH=%%D"
        )
    )
)

if not defined ENVPATH (
    echo No environment named "%ENVNAME%" found under %REPO%.
    endlocal
    exit /b 1
)

if not exist "%ENVPATH%\Scripts\python.exe" (
    echo "%ENVNAME%" has no Scripts\python.exe - is it a valid venv?
    endlocal
    exit /b 1
)
"%ENVPATH%\Scripts\python.exe" %REST%
set "RC=%errorlevel%"
endlocal & exit /b %RC%
