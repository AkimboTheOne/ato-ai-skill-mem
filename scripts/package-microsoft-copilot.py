#!/usr/bin/env python3
"""Empaqueta la proyección Microsoft 365 Copilot del skill fuente."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
from typing import NoReturn
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_ROOT = ROOT / "templates" / "integrations" / "microsoft-copilot"
PACKAGE_FILES = ("SKILL.md", "connection-contract.md")
CAPABILITY_CONTRACT = ROOT / "references" / "capability-contract.md"
CHANGE_CONTROL_CONTRACT = ROOT / "references" / "change-control-contract.md"
SKILL_VERSION_MARKER = "__SKILL_VERSION__"
NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")


def fail(message: str) -> NoReturn:
    raise SystemExit(f"error: {message}")


def read_version() -> str:
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        fail("VERSION no contiene una versión SemVer válida")
    return version


def read_git_revision() -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(ROOT), "rev-parse", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def read_git_worktree_state() -> str:
    try:
        dirty = subprocess.check_output(
            ["git", "-C", str(ROOT), "status", "--porcelain"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        return "dirty" if dirty else "clean"
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def parse_front_matter(path: Path) -> tuple[str, str, int]:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        fail(f"{path} no tiene YAML front matter")
    end = text.find("\n---\n", 4)
    if end < 0:
        fail(f"{path} no cierra el YAML front matter")
    front_matter = text[4:end].splitlines()
    values: dict[str, str] = {}
    for line in front_matter:
        match = re.fullmatch(r"(name|description):[ \t]*(.+)", line)
        if match:
            values[match.group(1)] = match.group(2).strip().strip('"\'')
    name = values.get("name", "")
    description = values.get("description", "")
    if not NAME_RE.fullmatch(name):
        fail("name debe usar lowercase kebab-case y tener entre 1 y 64 caracteres")
    if not description or "\n" in description:
        fail("description debe ser una línea no vacía")
    instruction_chars = len(text[end + 5 :])
    if instruction_chars >= 20_000:
        fail("las instrucciones deben tener menos de 20.000 caracteres")
    return name, description, instruction_chars


def validate_templates() -> tuple[str, str, int]:
    if not TEMPLATE_ROOT.is_dir():
        fail(f"falta el directorio de integración: {TEMPLATE_ROOT}")
    for relative in PACKAGE_FILES:
        path = TEMPLATE_ROOT / relative
        if path.is_symlink() or not path.is_file():
            fail(f"recurso de integración inexistente o no local: {relative}")
    if CAPABILITY_CONTRACT.is_symlink() or not CAPABILITY_CONTRACT.is_file():
        fail("falta el contrato de capacidades portable")
    if CHANGE_CONTROL_CONTRACT.is_symlink() or not CHANGE_CONTROL_CONTRACT.is_file():
        fail("falta el perfil portable de cambios controlados")
    return parse_front_matter(TEMPLATE_ROOT / "SKILL.md")


def metadata(version: str) -> bytes:
    payload = {
        "adapter_target": "microsoft-365-copilot-agent-builder",
        "source_revision": read_git_revision(),
        "source_worktree": read_git_worktree_state(),
        "skill_version": version,
        "vault_format": int((ROOT / "VAULT_FORMAT").read_text(encoding="utf-8").strip()),
        "package_schema": 1,
    }
    return (json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def write_zip(output: Path, version: str) -> None:
    if output.suffix.lower() != ".zip":
        fail("la salida debe tener extensión .zip")
    if output.exists():
        fail(f"la salida ya existe; elige otra ruta: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    resources: dict[str, bytes] = {}
    for relative in PACKAGE_FILES:
        content = (TEMPLATE_ROOT / relative).read_text(encoding="utf-8")
        if relative == "connection-contract.md":
            content = content.replace(SKILL_VERSION_MARKER, version)
        resources[relative] = content.encode("utf-8")
    resources["capability-contract.md"] = CAPABILITY_CONTRACT.read_bytes()
    resources["change-control-contract.md"] = CHANGE_CONTROL_CONTRACT.read_bytes()
    resources["package-metadata.json"] = metadata(version)
    with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
        for relative in sorted(resources):
            info = ZipInfo(relative, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, resources[relative])


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="ruta del ZIP a crear")
    args = parser.parse_args(argv)
    version = read_version()
    name, _, instruction_chars = validate_templates()
    write_zip(args.output.resolve(), version)
    print(f"paquete Microsoft 365 Copilot creado: {args.output.resolve()}")
    print(f"skill: {name}")
    print(f"source_version: {version}")
    print(f"instruction_chars: {instruction_chars}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
