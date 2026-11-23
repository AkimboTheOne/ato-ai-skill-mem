#!/usr/bin/env python3
"""Valida la skill con el entorno de desarrollo del proyecto."""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
try:
    import yaml  # noqa: F401
except ImportError:
    sys.exit("Falta PyYAML. Instala requirements-dev.txt en el entorno de desarrollo; consulta README.md.")

with tempfile.TemporaryDirectory() as directory:
    skill = Path(directory) / "local-mem"
    skill.mkdir()
    shutil.copy2(root / "SKILL.md", skill / "SKILL.md")
    sys.exit(subprocess.call([sys.executable, str(root / "scripts/quick_validate.py"), str(skill)]))
