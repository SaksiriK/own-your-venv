# own-your-venv

You don't need a commercial package to manage your virtual environments.
This script will do it for you - for free, fast, and it lets you add a
comment to each one so you remember what it's for.

## The idea

Most people re-create a `.venv` with the same requirements in every project
folder, over and over. This is the opposite: one shared folder of
environments on your machine, and a single `vnvmgr` command that lists what
you've already got, activates one, or runs a script under one directly - so
you stop paying the disk space and setup time to rebuild an environment you
already made.

It's deliberately small and dependency-free - a `.bat` file for cmd.exe and
a PowerShell script for PowerShell, nothing to install. The idea matters
more than the code: a personal environment registry, not a package manager.

The script itself isn't the hard part - anyone with an AI coding assistant
can build this in an afternoon. What's worth sharing is the idea: stop
re-creating environments you already have, and just point at them instead.

## Setup

```
git clone https://github.com/SaksiriK/own-your-venv C:\own-your-venv
C:\own-your-venv\setup.bat
```

`setup.bat` (a thin wrapper so this works the same from cmd.exe or
PowerShell - `.ps1` files don't run by name from cmd.exe) is a one-time
step, safe to re-run. It:
- adds this folder to your PATH (User scope, no admin rights needed)
- adds a `vnvmgr` function to your PowerShell `$PROFILE` (see
  [Usage](#usage) below for why PowerShell needs that and cmd.exe doesn't)
- creates one starter venv, `example_env`, if this folder has no
  environments yet, so `vnvmgr` has something to show/activate right away

It auto-detects wherever you actually cloned to, so the folder above is
just an example - clone anywhere you like.

Open a new terminal window afterward and run `vnvmgr` - that's it.

## Usage

```
vnvmgr                           list environments, choose one to activate
vnvmgr <name>                   activate <name> in the current shell session
vnvmgr <name> script.py [args]  run script.py under <name>'s interpreter, no activation
vnvmgr new                      create a new environment
vnvmgr edit <name>              edit <name>'s comment.txt
vnvmgr freeze [name]            pip freeze > requirements.txt for one env, or all if no name
```

`vnvmgr <name>` activates in the current session: sets `VIRTUAL_ENV`,
prepends its `Scripts` to `PATH`, gives you a `deactivate` command.
`vnvmgr <name> script.py` skips activation entirely and just runs the
script under that environment's interpreter, forwarding its exit code -
useful for invoking a shared environment from another script or a CI job
without it needing its own `.venv`.

Bare `vnvmgr` shows a plain numbered list and a prompt - type a number or
name to activate, `new` to create an environment, `edit <name>` to edit a
comment, `freeze` to write `requirements.txt`, or `i` to print the full
command reference and the Python-code snippet above.

Any venv (anything with a `pyvenv.cfg`) is picked up automatically — just
drop the environment's folder into `C:\own-your-venv`, no registration step.

**In cmd.exe**, `vnvmgr` resolves to `vnvmgr.bat`, which activates directly
in that cmd.exe session.

**In PowerShell**, activation has to happen in your actual PowerShell
process, not a spawned one - a bare `vnvmgr` would otherwise resolve to
`vnvmgr.bat` via `PATH` too, activating inside a throwaway child process
and losing it the moment that process exits. That's what the `$PROFILE`
function `setup.ps1` adds is for: it makes `vnvmgr` call `vnvmgr.ps1`
directly, in your actual session, where activation persists.

## Describing an environment

```
vnvmgr edit <name>
```

Shows that environment's current comment, then prompts for a new one-line
description and overwrites `comment.txt` with it (blank cancels, leaving it
unchanged). `vnvmgr`'s listing shows it next to that entry - a reminder of
what each one is actually for, since names alone rarely stay meaningful:

```
gis_env - a general GIS environment venv
```

`vnvmgr edit` with no name shown first lists the environments and asks
which one before asking for the new comment.

## From Python code

To have one script launch another under a specific shared environment:

```python
import subprocess
subprocess.run([r"C:\own-your-venv\<name>\Scripts\python.exe", "script.py", "--arg", "value"])
```

Since `C:\own-your-venv` is on PATH, `vnvmgr` itself is also callable the same way:

```python
subprocess.run(["vnvmgr", "<name>", "script.py", "--arg", "value"])
```

## IDE interpreter

Point VS Code / PyCharm's interpreter directly at the shared environment
instead of creating a project `.venv`:

```
C:\own-your-venv\<name>\Scripts\python.exe
```

## Adding packages

Environments here are shared across projects - `pip install <package>` while
one is active affects every project using it, not just yours. Activate
first (`vnvmgr <name>`), install deliberately, then:

```
vnvmgr freeze <name>
```

writes that environment's `requirements.txt` so the change is visible to
anyone else pointed at it. Leave off the name (`vnvmgr freeze`) to do every
environment at once - useful for refreshing all of them after a batch of
updates. Don't install ad hoc for a single project's needs without
recording it - anything else already pointed at that environment inherits
the change too.

## Adding a new environment

```
vnvmgr new
```

(equivalent to running `create-venv` directly.) Picks the latest available
Python automatically (prints which one), prompts for a name, creates the
venv directly inside this folder, and optionally records its `comment.txt`
in the same step. `vnvmgr` picks it up next time it scans this folder - no
registration step. Pass `-PythonVersion` to pin a specific version instead
(see `create-venv -?`).

Non-interactively:

```
create-venv new_env_name -PythonVersion 3.11
```

Or create it by hand the same way and add a `comment.txt` alongside it so
future-you knows what it's for:

```
python -m venv C:\own-your-venv\new_env_name
```
