<#
.Synopsis
One-time setup after cloning this repo: adds it to your PATH and wires up
a `vnvmgr` PowerShell function, so `vnvmgr`/`create-venv` work immediately
in both cmd.exe and PowerShell without any further manual steps.

.Description
Run this once, right after cloning. Safe to re-run - both steps check
first and skip anything already in place, so running it again (e.g. after
moving the clone) just fixes up what's missing.

Adds this folder to your *User*-scope PATH (no admin rights needed) rather
than Machine-scope, and uses [Environment]::SetEnvironmentVariable rather
than `setx`, which has a long-standing bug that silently truncates PATH at
1024 characters on a heavily-configured machine.

Also appends a `vnvmgr` function to your PowerShell $PROFILE. This is
necessary, not cosmetic: vnvmgr.bat activates by running directly in your
cmd.exe session, but PowerShell resolves a bare `vnvmgr` to vnvmgr.bat too
(via PATH), which would activate inside a throwaway child process and lose
it the instant that process exits. The profile function makes `vnvmgr` in
PowerShell call vnvmgr.ps1 directly instead, in your actual session, where
activation actually persists.

Then, if this folder has no environments at all yet (a fresh clone),
creates one starter venv (example_env) so there's something to see/activate
immediately, without a separate manual `vnvmgr new` step. Skipped if any
environment already exists, so re-running this on a machine you've already
been using won't add clutter.

Finally, writes a `.setup-complete` marker - vnvmgr.bat/.ps1 check for it
and auto-run this script if it's missing, so even skipping this step
entirely and just running `vnvmgr`/`.\vnvmgr.ps1` from inside this folder
still bootstraps everything on first use.

.Example
.\setup.ps1
Adds this repo to PATH, sets up the PowerShell profile function, and
creates a starter venv if this is a fresh clone with no environments yet.
#>

$RepoRoot = $PSScriptRoot

Write-Host "Setting up own-your-venv at $RepoRoot" -ForegroundColor Cyan
Write-Host ""

# 1. PATH, so `vnvmgr`/`create-venv` resolve by name in cmd.exe, and so
# vnvmgr.bat (the cmd.exe path) works right away with no further steps.
$currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathEntries = @()
if ($currentPath) {
    $pathEntries = $currentPath -split ';' | Where-Object { $_ }
}

if ($pathEntries -contains $RepoRoot) {
    Write-Host "PATH already includes $RepoRoot" -ForegroundColor DarkGray
}
else {
    $newPath = if ($currentPath) { "$currentPath;$RepoRoot" } else { $RepoRoot }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Host "Added to your PATH: $RepoRoot" -ForegroundColor Green
    Write-Host "  (open a new terminal window for this to take effect)" -ForegroundColor DarkGray
}

Write-Host ""

# 2. $PROFILE, so `vnvmgr` also works directly in PowerShell - see the
# .Description above for why this is needed, not just PATH.
$profileLine = "function vnvmgr { & `"$RepoRoot\vnvmgr.ps1`" @args }"

$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

$existingProfile = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($existingProfile -and $existingProfile.Contains($profileLine)) {
    Write-Host "`$PROFILE already has the vnvmgr function" -ForegroundColor DarkGray
}
else {
    Add-Content -Path $PROFILE -Value "`n$profileLine"
    Write-Host "Added to `$PROFILE ($PROFILE):" -ForegroundColor Green
    Write-Host "  $profileLine" -ForegroundColor DarkGray
    Write-Host "  (open a new PowerShell window, or run: . `$PROFILE)" -ForegroundColor DarkGray
}

Write-Host ""

# 3. A starter venv, so `vnvmgr` has something to show/activate right away
# on a fresh clone - skip if any environment already exists here.
$hasEnvironment = @(Get-ChildItem -Path $RepoRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'pyvenv.cfg') }).Count -gt 0

if ($hasEnvironment) {
    Write-Host "Environment(s) already exist here - not creating a starter one." -ForegroundColor DarkGray
}
else {
    & (Join-Path $RepoRoot 'create-venv.ps1') -Name 'example_env' -Comment 'starter environment - safe to delete'
}

Set-Content -Path (Join-Path $RepoRoot '.setup-complete') -Value 'vnvmgr.bat/.ps1 check for this file to auto-run setup.bat on first use - safe to delete, it just re-runs setup next time.' -NoNewline

Write-Host ""
Write-Host "Setup complete. Open a new terminal window and run: vnvmgr" -ForegroundColor Cyan
