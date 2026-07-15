<#
.Synopsis
List, activate, or run under Python virtual/conda environments stored under
this repository.

.Description
Scans the folder this script lives in for immediate subfolders that are
either a plain Python venv (contain pyvenv.cfg) or a conda environment
(contain a conda-meta folder). With no arguments, prints a numbered list and
prompts for a selection. With -Name only, activates that environment
directly. With -Name plus trailing arguments, instead runs those arguments
through that environment's python directly (no activation) and forwards its
exit code - for invoking a shared environment from another script without
needing your own per-project .venv or conda env.

Plain venvs activate via their own Scripts\Activate.ps1 (sets $env:VIRTUAL_ENV,
prepends $env:PATH, defines a global `deactivate`). Conda envs activate via
`conda activate <path>`, which requires conda's PowerShell hook to already be
loaded in this session (i.e. `conda init powershell` has been run - this is
what makes bare `conda` work at all; see your $PROFILE).

.Parameter Name
Folder name of the environment (e.g. "gis_env" or "yolov5_env_2").
If omitted, the available environments are listed for interactive selection.

.Parameter ScriptArgs
Optional command and arguments to run under Name's python, e.g. a script
path and its arguments. If given, runs immediately instead of activating.

.Example
venv
Lists all environments found and prompts you to pick one.

.Example
venv gis_env
Activates the "gis_env" venv in the current session.

.Example
venv yolov5_env_2 myscript.py --input data.tif
Runs myscript.py under yolov5_env_2 (a conda env) and forwards its exit code.
#>
param(
    [Parameter(Position = 0)]
    [string]$Name,

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

$RepoRoot = $PSScriptRoot

function Get-VenvComment {
    param([string]$EnvPath)
    $commentFile = Join-Path $EnvPath 'comment.txt'
    if (Test-Path $commentFile) {
        return (Get-Content $commentFile -TotalCount 1 -ErrorAction SilentlyContinue)
    }
    return $null
}

function Get-VenvList {
    Get-ChildItem -Path $RepoRoot -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
            if (Test-Path (Join-Path $_.FullName 'pyvenv.cfg')) {
                [PSCustomObject]@{ Name = $_.Name; FullName = $_.FullName; Kind = 'venv'; Comment = (Get-VenvComment $_.FullName) }
            }
            elseif (Test-Path (Join-Path $_.FullName 'conda-meta')) {
                [PSCustomObject]@{ Name = $_.Name; FullName = $_.FullName; Kind = 'conda'; Comment = (Get-VenvComment $_.FullName) }
            }
        } |
        Sort-Object Name
}

function Resolve-VenvByName {
    param([string]$Candidate, $Venvs)
    $Venvs | Where-Object { $_.Name -eq $Candidate }
}

function Write-VenvList {
    param($Venvs)
    Write-Host "Environments in $RepoRoot :" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Venvs.Count; $i++) {
        $line = "  [{0}] {1} ({2})" -f ($i + 1), $Venvs[$i].Name, $Venvs[$i].Kind
        if ($Venvs[$i].Comment) {
            $line += " - $($Venvs[$i].Comment)"
        }
        Write-Host $line
    }
}

function Write-VenvHelp {
    Write-Host "Shared environments in $RepoRoot - no need to create a project .venv or conda env." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  venv                          list environments, choose one to activate"
    Write-Host "  venv <name>                   activate <name> in this shell session"
    Write-Host "  venv <name> script.py [args]  run script.py under <name>'s python, no activation"
    Write-Host ""
    Write-Host "From Python code, to run something under a shared env:"
    Write-Host "  import subprocess"
    Write-Host "  subprocess.run([r`"$RepoRoot\<name>\Scripts\python.exe`", `"script.py`", `"--arg`", `"value`"])"
    Write-Host "  (conda envs: python.exe sits at r`"$RepoRoot\<name>\python.exe`" instead of \Scripts\)"
    Write-Host ""
}

function Get-PythonExe {
    param($EnvInfo)
    if ($EnvInfo.Kind -eq 'conda') {
        return Join-Path $EnvInfo.FullName 'python.exe'
    }
    return Join-Path $EnvInfo.FullName 'Scripts\python.exe'
}

$venvs = @(Get-VenvList)

if ($venvs.Count -eq 0) {
    Write-Host "No environments found under $RepoRoot (looked for subfolders containing pyvenv.cfg or conda-meta)." -ForegroundColor Yellow
    return
}

if (Test-Path Env:VIRTUAL_ENV) {
    Write-Host "Currently active (venv): $env:VIRTUAL_ENV" -ForegroundColor DarkGray
}
if (Test-Path Env:CONDA_PREFIX) {
    Write-Host "Currently active (conda): $env:CONDA_PREFIX" -ForegroundColor DarkGray
}

$target = $null

if ($Name) {
    $target = Resolve-VenvByName -Candidate $Name -Venvs $venvs
    if (-not $target) {
        Write-Host "No environment named '$Name' found." -ForegroundColor Red
        Write-VenvList -Venvs $venvs
        return
    }
}
else {
    Write-VenvHelp
    Write-VenvList -Venvs $venvs
    $choice = Read-Host "Enter number or name to activate (blank to cancel)"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        return
    }
    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $venvs.Count) {
            $target = $venvs[$idx]
        }
    }
    else {
        $target = Resolve-VenvByName -Candidate $choice -Venvs $venvs
    }
    if (-not $target) {
        Write-Host "Invalid selection '$choice'." -ForegroundColor Red
        return
    }
}

if ($ScriptArgs -and $ScriptArgs.Count -gt 0) {
    if ($target.Kind -eq 'conda') {
        conda run -p $target.FullName --no-capture-output python @ScriptArgs
        return
    }
    $pythonExe = Get-PythonExe -EnvInfo $target
    if (-not (Test-Path $pythonExe)) {
        Write-Host "'$($target.Name)' has no Scripts\python.exe - is it a valid venv?" -ForegroundColor Red
        return
    }
    & $pythonExe @ScriptArgs
    return
}

if ($target.Kind -eq 'conda') {
    $condaCmd = Get-Command conda -ErrorAction SilentlyContinue
    if (-not $condaCmd -or $condaCmd.CommandType -eq 'Application') {
        Write-Host "conda isn't hooked into this PowerShell session (need 'conda init powershell', then reopen your shell)." -ForegroundColor Red
        Write-Host "You can still run scripts without activating: venv $($target.Name) script.py [args]" -ForegroundColor DarkGray
        return
    }
    conda activate $target.FullName
    Write-Host "Activated '$($target.Name)' (conda)" -ForegroundColor Green
    Write-Host "  $($target.FullName)" -ForegroundColor DarkGray
    return
}

$activateScript = Join-Path $target.FullName 'Scripts\Activate.ps1'
if (-not (Test-Path $activateScript)) {
    Write-Host "'$($target.Name)' has no Scripts\Activate.ps1 - is it a valid venv?" -ForegroundColor Red
    return
}

& $activateScript
Write-Host "Activated '$($target.Name)'" -ForegroundColor Green
Write-Host "  $($target.FullName)" -ForegroundColor DarkGray
