---
name: environment paths
description: hard-coded paths for Python env, tooling, and OS-specific gotchas
type: reference
---

Fill in for each project on first session:

- Python: `~/venvs/{{PROJECT_NAME}}-venv/bin/python`
- pytest: `~/venvs/{{PROJECT_NAME}}-venv/bin/pytest`
- Repo: `~/Desktop/repo/<public|private>/{{PROJECT_NAME}}`

**macOS iCloud trap (carried from omni-sense lesson):** Never put venv in `~/Desktop/` or `~/Documents/` if iCloud Drive sync is on. fileproviderd intercepts every `.pyc` read; `import torch` can take 20+ minutes instead of 1 second. Always venv in `~/venvs/` outside iCloud, symlink into project if needed.

**Other gotchas to record per-project**:
- macOS cv2 windowing must be on main thread (if using opencv)
- ...
