# Creating and using an environment in own-your-venv

This is the step-by-step for a developer who needs a Python environment for
a new project: check what already exists first, and only create a new one
if nothing here already covers it.

## 1. Check what already exists

```
vnvmgr
```

Lists every environment in this folder along with its `comment.txt`
description. If one already has what you need, skip straight to
[Using it](#4-using-it-in-development) - don't create a duplicate.

## 2. Create a new environment

Pick a short, descriptive folder name (e.g. `enmap_env`, not `env2`) -
whatever you name the folder is the name you'll type into `vnvmgr` later.

```
vnvmgr new
```

(same as running `create-venv` directly). Prompts for a Python version
(blank for the latest - with the `py` launcher installed, every version it
knows about; without it, whichever single Python is actually on `PATH`)
and a name, then creates the venv directly inside this folder. Nothing
else needs registering - `vnvmgr` finds it automatically next time it
scans this folder (it looks for `pyvenv.cfg`).

## 3. Describe it

`vnvmgr new` asks for a one-line description at the end and writes it to
`comment.txt` for you. To change it later, `vnvmgr edit my_new_env` shows
the current one and prompts for a replacement. If you created the venv by
hand instead (`python -m venv C:\own-your-venv\my_new_env`), add that file
yourself:

```
Environment for the enmap raster-processing pipeline
```

in `C:\own-your-venv\my_new_env\comment.txt`. This is the only thing about your
environment that's worth putting in git - see [.gitignore](.gitignore). The
environment itself stays local.

## 4. Using it in development

Activate it in your terminal:

```
vnvmgr my_new_env
```

(In PowerShell, this needs the `$PROFILE` function `setup.ps1` adds - see
[README.md](README.md#setup) if you haven't run that yet.)

This behaves like a normal activated environment - `pip`/`python` resolve to
it, and `deactivate` exits it. Or, in your IDE, skip activation and just
point the interpreter directly at:

```
C:\own-your-venv\my_new_env\Scripts\python.exe
```

## 5. Installing packages

Activate first (`vnvmgr my_new_env`), then install as usual (`pip install
<package>`). Since the environment is shared, also update its requirements
file so the next person (including future you) knows what's expected in it:

```
pip freeze > C:\own-your-venv\my_new_env\requirements.txt
```

Don't install packages into a shared environment for a one-off need without
recording it - anything else already pointed at that environment inherits
the change too.

## 6. Running/executing code

For one-off runs or calling this from another script/CI job, skip
activation entirely:

```
vnvmgr my_new_env script.py --arg value
```

This runs `script.py` directly under that environment's interpreter and
forwards its exit code. From Python itself:

```python
import subprocess
subprocess.run(["vnvmgr", "my_new_env", "script.py", "--arg", "value"])
```

See [README.md](README.md) for the full command reference.
