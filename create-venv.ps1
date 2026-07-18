<#
.Synopsis
Create a new Python venv directly inside this repository folder, so vnvmgr
picks it up immediately.

.Description
Uses the latest available Python automatically (no version prompt - just
prints which one it picked) and prompts for a folder name, then runs
`python -m venv` to create it right here alongside vnvmgr.ps1. Optionally
records a one-line comment.txt description, same as the manual workflow
in CONTRIBUTING.md.

With the Python launcher for Windows (py) installed, "latest" means the
newest version it knows about. Without it, it's whatever single "python"
is genuinely on PATH - and specifically NOT a currently-activated venv's
own python.exe, even if one is active, so a new environment is always
built from a stable base install rather than whatever happened to be
active on someone's screen at the time. Pass -PythonVersion to pin a
specific version instead (useful for scripted/non-interactive use).

.Parameter Name
Folder name for the new environment. If omitted, you'll be prompted.

.Parameter PythonVersion
Version to use (e.g. "3.11"), overriding the automatic latest-version
pick. Without the py launcher installed, this must match the single
Python version actually found - there's nothing else to switch to.

.Example
create-venv
Uses the latest Python automatically, prompts for a name, creates the venv.

.Example
create-venv gis_env2 -PythonVersion 3.11
Creates gis_env2 using Python 3.11 specifically, with no prompts.
#>
param(
    [Parameter(Position = 0)]
    [string]$Name,

    [string]$PythonVersion
)

$RepoRoot = $PSScriptRoot

# vnvmgr checks this marker to know whether creation actually succeeded,
# since a failure here returns normally rather than a distinct exit code
# (this script can be called via `&` from within vnvmgr.ps1's own session,
# where `exit` would risk closing that whole PowerShell window, not just
# this script). Cleared up front so a stale marker from an earlier run
# can't be mistaken for success.
$markerFile = Join-Path $env:TEMP 'own-your-venv-created.txt'
Remove-Item -Path $markerFile -ErrorAction SilentlyContinue

function Get-PyLauncherVersions {
    $py = Get-Command py -ErrorAction SilentlyContinue
    if (-not $py) {
        return $null
    }
    $lines = & py -0p 2>$null
    if (-not $lines) {
        return $null
    }
    $versions = foreach ($line in $lines) {
        if ($line -match '-V:(\d+\.\d+)|-(\d+\.\d+)(?:-\d+)?\s') {
            $version = if ($matches[1]) { $matches[1] } else { $matches[2] }
            [PSCustomObject]@{ Version = $version; IsDefault = ($line -match '\*') }
        }
    }
    return @($versions | Sort-Object Version -Unique -Descending)
}

function Get-BasePython {
    # Get-Command python only returns the first PATH match by default, which
    # is the currently-activated venv's own python.exe if one is active -
    # using that to build a NEW venv would tie it to whichever env happened
    # to be active on someone's screen at creation time, not a stable base
    # install. Look through every match and skip anything living under this
    # repo (any of our own managed environments, active or not).
    $candidates = @(Get-Command python -All -ErrorAction SilentlyContinue)
    foreach ($candidate in $candidates) {
        if ($candidate.Source -notlike "$RepoRoot\*") {
            return $candidate
        }
    }
    return $null
}

$pyVersions = Get-PyLauncherVersions

if ($pyVersions -and $pyVersions.Count -gt 0) {
    if (-not $PythonVersion) {
        $default = ($pyVersions | Where-Object IsDefault | Select-Object -First 1)
        if (-not $default) { $default = $pyVersions[0] }
        $PythonVersion = $default.Version
        Write-Host "Using Python $PythonVersion (latest)." -ForegroundColor Cyan
    }
    if (-not ($pyVersions | Where-Object { $_.Version -eq $PythonVersion })) {
        Write-Host "Python $PythonVersion isn't installed. Available: $($pyVersions.Version -join ', ')" -ForegroundColor Red
        return
    }
    $pythonCmd = { param($TargetPath) & py "-$PythonVersion" -m venv $TargetPath }
}
else {
    $basePython = Get-BasePython
    if (-not $basePython) {
        Write-Host "No 'py' launcher, and no 'python' on PATH outside this repo's own environments - install Python first." -ForegroundColor Red
        return
    }
    $versionOutput = & $basePython.Source --version 2>&1
    $detectedVersion = $null
    if ($versionOutput -match '(\d+\.\d+)\.\d+') {
        $detectedVersion = $matches[1]
    }
    if (-not $PythonVersion) {
        Write-Host "Using $versionOutput at $($basePython.Source) (no py launcher installed, so this is the only one available)." -ForegroundColor Cyan
        $PythonVersion = $detectedVersion
    }
    if ($detectedVersion -and $PythonVersion -ne $detectedVersion) {
        Write-Host "Only Python $detectedVersion is available - no py launcher installed to switch versions. Install the Python launcher for Windows (py) for multi-version support." -ForegroundColor Red
        return
    }
    $pythonCmd = { param($TargetPath) & $basePython.Source -m venv $TargetPath }
}

if (-not $Name) {
    $Name = Read-Host "Name for the new environment"
}
if ([string]::IsNullOrWhiteSpace($Name)) {
    Write-Host "A name is required." -ForegroundColor Red
    return
}

$targetPath = Join-Path $RepoRoot $Name
if (Test-Path $targetPath) {
    Write-Host "'$Name' already exists at $targetPath." -ForegroundColor Red
    return
}

Write-Host "Creating '$Name'..." -ForegroundColor Cyan
& $pythonCmd $targetPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "venv creation failed (exit code $LASTEXITCODE)." -ForegroundColor Red
    return
}

$comment = Read-Host "One-line description for comment.txt (blank to skip)"
if (-not [string]::IsNullOrWhiteSpace($comment)) {
    Set-Content -Path (Join-Path $targetPath 'comment.txt') -Value $comment -NoNewline
}

Write-Host "Created '$Name' at $targetPath" -ForegroundColor Green
Write-Host "  vnvmgr $Name" -ForegroundColor DarkGray
Set-Content -Path $markerFile -Value $Name -NoNewline
