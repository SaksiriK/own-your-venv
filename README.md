# own-your-venv

You don't need a commercial package to manage your virtual environments.
This script will do it for you - for free, fast, and it lets you add a
comment to each one so you remember what it's for.

## The idea

Most people re-create a `.venv` (or a conda env) with the same requirements
in every project folder, over and over. This is the opposite: one shared
folder of environments on your machine, and a single `venv` command that
lists what you've already got, activates one, or runs a script under one
directly - so you stop paying the disk space and setup time to rebuild an
environment you already made.

It's deliberately small and dependency-free - a PowerShell function plus a
`.bat` file, nothing to install. The idea matters more than the code: a
personal environment registry, not a package manager.

The script itself isn't the hard part - anyone with an AI coding assistant
can build this in an afternoon. What's worth sharing is the idea: stop
re-creating environments you already have, and just point at them instead.

## Usage

Works the same from PowerShell or cmd.exe:

```
venv                          list environments, choose one to activate
venv <name>                   activate <name> in the current shell session
venv <name> script.py [args]  run script.py under <name>'s interpreter, no activation
```

`venv <name>` activates in the current session (for a plain venv: sets
`VIRTUAL_ENV`, prepends its `Scripts` to `PATH`, gives you a `deactivate`
command; for a conda env: runs `conda activate <path>`). `venv <name>
script.py` skips activation entirely and just runs the script under that
environment's interpreter, forwarding its exit code - useful for invoking a
shared environment from another script or a CI job without it needing its
own `.venv` or conda env.

Both plain venvs (anything with a `pyvenv.cfg`) and conda environments
(anything with a `conda-meta` folder) are picked up automatically - just
drop the environment's folder in here, no registration step.

## Describing an environment

Add a `comment.txt` file (one line of plain text) inside any environment's
folder, and `venv`'s listing will show it next to that entry - a reminder of
what each one is actually for, since names alone rarely stay meaningful:

```
gis_env (venv) - a general GIS environment venv
```

## From Python code

To have one script launch another under a specific shared environment:

```python
import subprocess
subprocess.run([r"E:\virtual_venv\<name>\Scripts\python.exe", "script.py", "--arg", "value"])
```

(Conda envs: the interpreter sits at `E:\virtual_venv\<name>\python.exe`
instead of `\Scripts\python.exe`.)

Since `E:\virtual_venv` is on PATH, `venv` itself is also callable the same way:

```python
subprocess.run(["venv", "<name>", "script.py", "--arg", "value"])
```

## IDE interpreter

Point VS Code / PyCharm's interpreter directly at the shared environment
instead of creating a project `.venv`:

```
E:\virtual_venv\<name>\Scripts\python.exe
```

## Adding packages

Environments here are shared across projects - `pip install <package>` (or
`conda install`) while one is active affects every project using it, not
just yours. Activate first (`venv <name>`), install deliberately, and update
that environment's requirements file so the change is visible - don't
install ad hoc for a single project's needs without knowing it affects
everything else pointed at that environment.

## Adding a new environment

Create it directly inside this folder - it's picked up automatically:

```
python -m venv E:\virtual_venv\new_env_name
```

or copy/create a conda env here the same way. Add a `comment.txt` alongside
it so future-you knows what it's for.
