"""Resolución explícita y acotada de vaults fuente y consumidoras."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re

from .vault import VaultError


MARKER_NAME = ".ato-ai-skill-mem-version.yml"
KIND_RE = re.compile(r"^vault_kind:\s*([^\s#]+)\s*$", re.MULTILINE)


@dataclass(frozen=True)
class AuthorizedVault:
    root: Path
    role: str
    owner: Path

    def as_dict(self) -> dict[str, str]:
        return {"role": self.role, "vault": self.root.as_posix()}


def _local_directory(path: Path, label: str) -> Path:
    candidate = path.expanduser()
    if not candidate.exists():
        raise VaultError(f"{label} no existe: {path}")
    if candidate.is_symlink() or not candidate.is_dir():
        raise VaultError(f"{label} no es un directorio local: {path}")
    return candidate.resolve()


def _local_file(path: Path, label: str) -> Path:
    if path.is_symlink() or not path.is_file():
        raise VaultError(f"{label} no es un archivo local: {path}")
    return path


def _vault_kind(root: Path) -> str | None:
    marker = root / MARKER_NAME
    if marker.is_symlink():
        raise VaultError(f"manifiesto de vault no es un archivo local: {marker}")
    if not marker.exists():
        return None
    _local_file(marker, f"manifiesto de vault {marker}")
    content = marker.read_text(encoding="utf-8")
    match = KIND_RE.search(content)
    return match.group(1) if match else None


def _source_vault(source_root: Path) -> AuthorizedVault:
    owner = _local_directory(source_root, "SOURCE_ROOT")
    for relative in ("VERSION", "VAULT_FORMAT", "scripts"):
        candidate = owner / relative
        if relative == "scripts":
            _local_directory(candidate, f"componente fuente {candidate}")
        else:
            _local_file(candidate, f"componente fuente {candidate}")
    root = _local_directory(owner / "vault", "vault fuente")
    if _vault_kind(root) != "source":
        raise VaultError(f"la vault fuente no declara vault_kind: source: {root}")
    return AuthorizedVault(root=root, role="source", owner=owner)


def _consumer_vault(project_root: Path) -> AuthorizedVault:
    owner = _local_directory(project_root, "PROJECT_PATH")
    if (owner / "VERSION").is_file() and (owner / "VAULT_FORMAT").is_file() and (owner / "scripts").is_dir():
        raise VaultError("la raíz de la fuente no puede usarse como proyecto consumidor")
    _local_directory(owner / "mem", "directorio mem del consumidor")
    root = _local_directory(owner / "mem" / "vault", "vault consumidora")
    if _vault_kind(root) == "source":
        raise VaultError(f"la vault consumidora declara vault_kind: source: {root}")
    return AuthorizedVault(root=root, role="consumer", owner=owner)


def resolve_authorized_vault(source_root: Path | None, project_root: Path | None) -> AuthorizedVault:
    if (source_root is None) == (project_root is None):
        raise VaultError("debe especificarse exactamente uno de --source o --target")
    if source_root is not None:
        return _source_vault(source_root)
    assert project_root is not None
    return _consumer_vault(project_root)
