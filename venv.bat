@echo off
rem List, activate, or run under Python venvs / conda environments in this
rem folder.
rem   venv                       - lists environments, prompts for a selection
rem   venv <name>                - activates that environment in this cmd session
rem   venv <name> script.py args - runs script.py under <name>'s python
rem                                directly (no activation) and forwards its
rem                                exit code - for invoking a shared env from
rem                                another script without its own .venv/conda env.
rem
rem Plain venvs (pyvenv.cfg) activate via their own Scripts\activate.bat.
rem Conda envs (conda-meta) activate via "conda activate <path>", which just
rem needs condabin on PATH (no special cmd.exe init required, unlike PowerShell).

set "REPO=%~dp0"
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"

if not "%~2"=="" goto :runmode

setlocal enabledelayedexpansion
rem Discovery/selection below is scoped by setlocal (safe: delayed expansion
rem needs it). Only TARGET/TARGETNAME/TARGETKIND are carried past "endlocal"
rem so the actual activation runs in the caller's real environment, not a
rem scope that gets discarded when this script ends.

set "count=0"
for /d %%D in ("%REPO%\*") do (
    if exist "%%D\pyvenv.cfg" (
        set /a count+=1
        set "venv!count!=%%~nxD"
        set "venvpath!count!=%%D"
        set "kind!count!=venv"
        set "comment!count!="
        if exist "%%D\comment.txt" set /p "comment!count!=" 0<"%%D\comment.txt"
    ) else if exist "%%D\conda-meta" (
        set /a count+=1
        set "venv!count!=%%~nxD"
        set "venvpath!count!=%%D"
        set "kind!count!=conda"
        set "comment!count!="
        if exist "%%D\comment.txt" set /p "comment!count!=" 0<"%%D\comment.txt"
    )
)

if "%count%"=="0" (
    echo No environments found under %REPO% ^(looked for subfolders containing pyvenv.cfg or conda-meta^).
    endlocal
    exit /b 1
)

set "TARGET="
set "TARGETNAME="
set "TARGETKIND="

if not "%~1"=="" (
    for /l %%i in (1,1,%count%) do (
        if /i "!venv%%i!"=="%~1" (
            set "TARGET=!venvpath%%i!"
            set "TARGETNAME=!venv%%i!"
            set "TARGETKIND=!kind%%i!"
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

call :showhelp
call :listenvs
set /p "choice=Enter number or name to activate (blank to cancel): "
if "!choice!"=="" (
    endlocal
    exit /b 0
)

echo(!choice!| findstr /r "^[0-9][0-9]*$" >nul
if !errorlevel! equ 0 (
    if !choice! geq 1 if !choice! leq %count% (
        set "TARGET=!venvpath%choice%!"
        set "TARGETNAME=!venv%choice%!"
        set "TARGETKIND=!kind%choice%!"
    )
) else (
    for /l %%i in (1,1,%count%) do (
        if /i "!venv%%i!"=="!choice!" (
            set "TARGET=!venvpath%%i!"
            set "TARGETNAME=!venv%%i!"
            set "TARGETKIND=!kind%%i!"
        )
    )
)

if not defined TARGET (
    echo Invalid selection "!choice!".
    endlocal
    exit /b 1
)

:activate
rem Carry TARGET/TARGETNAME/TARGETKIND out of the setlocal scope so the
rem activation's env changes land in the real caller session instead of
rem being discarded.
endlocal & set "TARGET=%TARGET%" & set "TARGETNAME=%TARGETNAME%" & set "TARGETKIND=%TARGETKIND%"

if "%TARGETKIND%"=="conda" (
    call conda activate "%TARGET%"
    echo Activated "%TARGETNAME%" ^(conda^)
    echo   %TARGET%
    exit /b 0
)

if not exist "%TARGET%\Scripts\activate.bat" (
    echo "%TARGETNAME%" has no Scripts\activate.bat - is it a valid venv?
    exit /b 1
)
call "%TARGET%\Scripts\activate.bat"
echo Activated "%TARGETNAME%"
echo   %TARGET%
exit /b 0

:listenvs
echo Environments in %REPO% :
for /l %%i in (1,1,%count%) do call :print_one %%i
exit /b 0

:print_one
if defined comment%1 (
    echo   [%1] !venv%1! ^(!kind%1!^) - !comment%1!
) else (
    echo   [%1] !venv%1! ^(!kind%1!^)
)
exit /b 0

:showhelp
echo Shared environments in %REPO% - no need to create a project .venv or conda env.
echo(
echo   venv                          list environments, choose one to activate
echo   venv ^<name^>                   activate ^<name^> in this shell session
echo   venv ^<name^> script.py [args]  run script.py under ^<name^>'s python, no activation
echo(
echo From Python code, to run something under a shared env:
echo   import subprocess
echo   subprocess.run^([r"%REPO%\<name>\Scripts\python.exe", "script.py", "--arg", "value"]^)
echo   ^(conda envs: python.exe sits at %REPO%\^<name^>\python.exe instead of \Scripts\^)
echo(
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
set "ENVKIND="
for /d %%D in ("%REPO%\*") do (
    if /i "%%~nxD"=="%ENVNAME%" (
        if exist "%%D\pyvenv.cfg" (
            set "ENVPATH=%%D"
            set "ENVKIND=venv"
        ) else if exist "%%D\conda-meta" (
            set "ENVPATH=%%D"
            set "ENVKIND=conda"
        )
    )
)

if not defined ENVPATH (
    echo No environment named "%ENVNAME%" found under %REPO%.
    endlocal
    exit /b 1
)

if "%ENVKIND%"=="conda" (
    call conda run -p "%ENVPATH%" --no-capture-output python %REST%
    set "RC=%errorlevel%"
    endlocal & exit /b %RC%
)

if not exist "%ENVPATH%\Scripts\python.exe" (
    echo "%ENVNAME%" has no Scripts\python.exe - is it a valid venv?
    endlocal
    exit /b 1
)
"%ENVPATH%\Scripts\python.exe" %REST%
set "RC=%errorlevel%"
endlocal & exit /b %RC%
