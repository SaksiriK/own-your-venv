# Creating and using an environment in own-your-venv

This is the step-by-step for a developer who needs a Python environment for
a new project: check what already exists first, and only create a new one
if nothing here already covers it.

## 1. Check what already exists

```
venv
```

Lists every environment in this folder along with its `comment.txt`
description. If one already has what you need, skip straight to
[Using it](#4-using-it-in-development) - don't create a duplicate.

## 2. Create a new environment

Pick a short, descriptive folder name (e.g. `enmap_env`, not `env2`) -
whatever you name the folder is the name you'll type into `venv` later.

**Plain venv** (the default choice - use this unless you specifically need
conda):

```
python -m venv E:\virtual_venv\my_new_env
```

**Conda env** (if you need packages conda handles better than pip - GDAL,
CUDA toolkits, etc.):

```
conda create -p E:\virtual_venv\my_new_env python=3.11
```

Either way, nothing else needs registering - `venv` finds it automatically
next time it scans this folder (it looks for `pyvenv.cfg` for plain venvs,
`conda-meta` for conda envs).

## 3. Describe it

Add a `comment.txt` (one line of plain text) in the new environment's
folder, e.g. `E:\virtual_venv\my_new_env\comment.txt`:

```
Environment for the enmap raster-processing pipeline
```

This is the only thing about your environment that's worth putting in git -
see [.gitignore](.gitignore). The environment itself stays local.

## 4. Using it in development

Activate it in your terminal (works the same in PowerShell or cmd.exe):

```
venv my_new_env
```

This behaves like a normal activated environment - `pip`/`python` resolve to
it, and `deactivate` (venv) or `conda deactivate` (conda) exits it. Or, in
your IDE, skip activation and just point the interpreter directly at:

```
E:\virtual_venv\my_new_env\Scripts\python.exe        (plain venv)
E:\virtual_venv\my_new_env\python.exe                (conda env)
```

## 5. Installing packages

Activate first (`venv my_new_env`), then install as usual (`pip install
<package>` or `conda install <package>`). Since the environment is shared,
also update its requirements file so the next person (including future you)
knows what's expected in it:

```
pip freeze > E:\virtual_venv\my_new_env\requirements.txt
```

Don't install packages into a shared environment for a one-off need without
recording it - anything else already pointed at that environment inherits
the change too.

## 6. Running/executing code

For one-off runs or calling this from another script/CI job, skip
activation entirely:

```
venv my_new_env script.py --arg value
```

This runs `script.py` directly under that environment's interpreter and
forwards its exit code. From Python itself:

```python
import subprocess
subprocess.run(["venv", "my_new_env", "script.py", "--arg", "value"])
```

See [README.md](README.md) for the full command reference.
