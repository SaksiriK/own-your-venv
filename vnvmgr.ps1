<#
.Synopsis
List, activate, create, or edit Python virtual environments stored under
this repository - for use directly inside a PowerShell session.

.Description
Scans the folder this script lives in for immediate subfolders that are a
plain Python venv (contain pyvenv.cfg). With no arguments, prints a numbered
list and prompts for a selection - or "new" to create an environment, or
"edit <name>" to edit an environment's comment.txt. With -Name only,
activates that environment directly. With -Name plus trailing arguments,
instead runs those arguments through that environment's python directly (no
activation) and forwards its exit code - for invoking a shared environment
from another script without needing your own per-project .venv.

Activation runs Scripts\Activate.ps1 directly in this session (sets
$env:VIRTUAL_ENV, prepends $env:PATH, defines a global `deactivate`), so run
this script directly in an interactive PowerShell session - e.g. dot-source
it or wrap it in a $PROFILE function - rather than through vnvmgr.bat.
Invoking it as a spawned subprocess (which is what vnvmgr.bat is for, from
cmd.exe) can't make activation persist in the caller's session.

.Parameter Name
Folder name of the environment (e.g. "gis_env" or "yolov5_env_2"), or the
literal "new" (create an environment) or "edit" (edit a comment.txt, target
name taken from the first entry of -ScriptArgs, or prompted for). If Name is
omitted entirely, the available environments are listed for interactive
selection alongside the same "new"/"edit <name>" options.

.Parameter ScriptArgs
Optional command and arguments to run under Name's python, e.g. a script
path and its arguments. If given, runs immediately instead of activating.
When Name is "edit", only the first entry is used, as the target env name.

.Example
vnvmgr
Lists all environments found and prompts you to pick one, create one, or
edit one's comment.

.Example
vnvmgr gis_env
Activates the "gis_env" venv in the current session.

.Example
vnvmgr new
Creates a new environment (same prompts as create-venv.ps1).

.Example
vnvmgr edit gis_env
Prompts for a new one-line comment and overwrites gis_env's comment.txt.

.Example
vnvmgr yolov5_env_2 myscript.py --input data.tif
Runs myscript.py under yolov5_env_2's python and forwards its exit code.
#>
param(
    [Parameter(Position = 0)]
    [string]$Name,

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

$RepoRoot = $PSScriptRoot

# One-time bootstrap: if setup.ps1 has never completed here, run it now.
# This only matters when vnvmgr.ps1 is reachable at all without it - e.g.
# run as .\vnvmgr.ps1 from inside this folder, before the $PROFILE
# function exists - since a bare "vnvmgr" typed elsewhere can't resolve
# here in the first place without setup having already run. Single
# file-existence check, so this is effectively free on every other run
# once the marker exists.
if (-not (Test-Path (Join-Path $RepoRoot '.setup-complete'))) {
    & (Join-Path $RepoRoot 'setup.ps1')
}

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
                [PSCustomObject]@{ Name = $_.Name; FullName = $_.FullName; Comment = (Get-VenvComment $_.FullName) }
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
    Write-Host "Environments in $RepoRoot. select an option:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Venvs.Count; $i++) {
        $line = "  [{0}] {1}" -f ($i + 1), $Venvs[$i].Name
        if ($Venvs[$i].Comment) {
            $line += " - $($Venvs[$i].Comment)"
        }
        Write-Host $line
    }
}

function Write-VenvHelp {
    Write-Host "Shared environments in $RepoRoot - no need to create a project .venv." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  vnvmgr                          list environments, choose one to activate"
    Write-Host "  vnvmgr <name>                   activate <name> in this shell session"
    Write-Host "  vnvmgr <name> script.py [args]  run script.py under <name>'s python, no activation"
    Write-Host "  vnvmgr new                      create a new environment"
    Write-Host "  vnvmgr edit <name>              edit <name>'s comment.txt"
    Write-Host ""
    Write-Host "From Python code, to run something under a shared env:"
    Write-Host "  import subprocess"
    Write-Host "  subprocess.run([r`"$RepoRoot\<name>\Scripts\python.exe`", `"script.py`", `"--arg`", `"value`"])"
    Write-Host ""
}

function Get-PythonExe {
    param($EnvInfo)
    return Join-Path $EnvInfo.FullName 'Scripts\python.exe'
}

function Invoke-CreateNew {
    # create-venv.ps1 writes this marker file on success (it doesn't
    # reliably signal success/failure via exit code otherwise - using `exit`
    # in a script invoked via `&` from within this same session could close
    # the whole PowerShell window, not just that script). Clear any stale
    # one first so it can't be mistaken for success here.
    $markerFile = Join-Path $env:TEMP 'own-your-venv-created.txt'
    Remove-Item -Path $markerFile -ErrorAction SilentlyContinue
    & (Join-Path $RepoRoot 'create-venv.ps1')
    Write-Host ""
    if (Test-Path $markerFile) {
        Write-Host "Re-run vnvmgr to see the new environment." -ForegroundColor DarkGray
        Remove-Item -Path $markerFile -ErrorAction SilentlyContinue
    }
}

function Invoke-EditComment {
    param([string]$EditName, $Venvs)
    if (-not $EditName) {
        Write-VenvList -Venvs $Venvs
        $EditName = (Read-Host "Environment name to edit the comment for (blank to cancel)").Trim()
        if ([string]::IsNullOrWhiteSpace($EditName)) {
            return
        }
    }
    if ($EditName -match '^\d+$') {
        $idx = [int]$EditName - 1
        $editTarget = if ($idx -ge 0 -and $idx -lt $Venvs.Count) { $Venvs[$idx] } else { $null }
    }
    else {
        $editTarget = Resolve-VenvByName -Candidate $EditName -Venvs $Venvs
    }
    if (-not $editTarget) {
        Write-Host "No environment named '$EditName' found." -ForegroundColor Red
        return
    }
    if ($editTarget.Comment) {
        Write-Host "Current comment: $($editTarget.Comment)" -ForegroundColor DarkGray
    }
    $newComment = Read-Host "New one-line comment for '$($editTarget.Name)' (replaces the above, blank to cancel)"
    if ([string]::IsNullOrWhiteSpace($newComment)) {
        Write-Host "No change made." -ForegroundColor DarkGray
        return
    }
    Set-Content -Path (Join-Path $editTarget.FullName 'comment.txt') -Value $newComment -NoNewline
    Write-Host "Comment for '$($editTarget.Name)' updated." -ForegroundColor Green
}

if ($Name -eq 'new') {
    Invoke-CreateNew
    return
}

$venvs = @(Get-VenvList)

if ($Name -eq 'edit') {
    $editName = if ($ScriptArgs -and $ScriptArgs.Count -gt 0) { $ScriptArgs[0] } else { $null }
    Invoke-EditComment -EditName $editName -Venvs $venvs
    return
}

if ($venvs.Count -eq 0) {
    Write-Host "No environments found under $RepoRoot (looked for subfolders containing pyvenv.cfg)." -ForegroundColor Yellow
    Write-Host "Run 'vnvmgr new' to create one." -ForegroundColor Yellow
    return
}

if (Test-Path Env:VIRTUAL_ENV) {
    Write-Host "Currently active: $env:VIRTUAL_ENV" -ForegroundColor DarkGray
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
    Write-VenvList -Venvs $venvs
    $choice = (Read-Host "Enter number or name to activate, 'new' to create, 'edit ' to edit a comment, 'i' for info (blank to cancel)").Trim()
    if ([string]::IsNullOrWhiteSpace($choice)) {
        return
    }
    if ($choice -eq 'i') {
        Write-VenvHelp
        return
    }
    if ($choice -eq 'new') {
        Invoke-CreateNew
        return
    }
    if ($choice -eq 'edit' -or $choice -like 'edit *') {
        $editName = if ($choice -eq 'edit') { $null } else { $choice.Substring(5).Trim() }
        Invoke-EditComment -EditName $editName -Venvs $venvs
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
    $pythonExe = Get-PythonExe -EnvInfo $target
    if (-not (Test-Path $pythonExe)) {
        Write-Host "'$($target.Name)' has no Scripts\python.exe - is it a valid venv?" -ForegroundColor Red
        return
    }
    & $pythonExe @ScriptArgs
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
