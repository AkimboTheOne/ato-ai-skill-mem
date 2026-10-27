"""Lectura y análisis determinista de una vault formato 3."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
import os
import posixpath
from pathlib import Path
import re
import unicodedata
from urllib.parse import unquote, urlsplit

from .frontmatter import FrontMatter, FrontMatterError, parse_front_matter


RECORD_FIELDS = {
    "id",
    "type",
    "status",
    "created",
    "updated",
    "scope",
    "author",
    "sources",
    "related",
    "supersedes",
    "superseded_by",
}
RECORD_TYPES = {"decision", "convention", "lesson", "project-context"}
RECORD_STATUSES = {"active", "retired"}
ID_RE = re.compile(r"^\d{4}-\d{2}-\d{2}--[a-z0-9][a-z0-9-]*$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
MARKDOWN_LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)(?:\s+[^)]*)?\)")
INDEX_LINK_RE = re.compile(r"^\s*-\s+\[[^\]]*\]\(([^)]+)\)\s*$")


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    code: str
    message: str


@dataclass(frozen=True)
class Match:
    path: str
    line: int
    snippet: str


@dataclass(frozen=True)
class Relation:
    source: str
    relation: str
    target: str
    resolved: bool


class VaultError(ValueError):
    """Indica una entrada o una vault que no puede analizarse."""


def validate_root(root: Path) -> Path:
    root = root.expanduser()
    if not root.exists():
        raise VaultError(f"la vault no existe: {root}")
    if not root.is_dir() or root.is_symlink():
        raise VaultError(f"la vault no es un directorio local: {root}")
    return root.resolve()


def relative_path(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def _walk_local(root: Path):
    def onerror(error: OSError) -> None:
        raise error

    for current, directories, filenames in os.walk(root, topdown=True, followlinks=False, onerror=onerror):
        current_path = Path(current)
        directories[:] = sorted(
            name for name in directories if not (current_path / name).is_symlink()
        )
        for name in sorted(filenames):
            path = current_path / name
            if not path.is_symlink():
                yield path


def markdown_files(root: Path):
    for path in _walk_local(root):
        if path.suffix.lower() == ".md":
            yield path


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise VaultError(f"no se pudo leer {path}: {exc}") from exc


def _path_finding(root: Path, path: Path, line: int, code: str, message: str) -> Finding:
    return Finding(relative_path(root, path), line, code, message)


def _scalar_string(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _hrefs(value: object) -> list[str]:
    if value is None:
        return []
    values = value if isinstance(value, list) else [value]
    result: list[str] = []
    for item in values:
        if not isinstance(item, str):
            continue
        links = MARKDOWN_LINK_RE.findall(item)
        result.extend(links or [item.strip()])
    return [href for href in result if href]


def _anchor_slug(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value).casefold()
    normalized = re.sub(r"[^\w\s-]", "", normalized, flags=re.UNICODE)
    return re.sub(r"[-\s]+", "-", normalized).strip("-")


def _anchor_exists(path: Path, fragment: str) -> bool:
    if path.suffix.lower() != ".md":
        return False
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError):
        return False
    for line in lines:
        match = re.match(r"^#{1,6}\s+(.+?)\s*#*\s*$", line)
        if match and _anchor_slug(match.group(1)) == _anchor_slug(fragment):
            return True
    return False


def _contains_symlink(root: Path, relative_target: str) -> bool:
    candidate = root
    for part in Path(relative_target).parts:
        candidate /= part
        if candidate.is_symlink():
            return True
    return False


def resolve_local_target(root: Path, source: Path, href: str) -> tuple[str, bool]:
    parsed = urlsplit(href)
    if parsed.scheme or parsed.netloc:
        return href, True
    raw_path = unquote(parsed.path)
    source_relative = relative_path(root, source)
    source_directory = posixpath.dirname(source_relative)
    target = posixpath.normpath(posixpath.join(source_directory, raw_path or posixpath.basename(source_relative)))
    if target == ".":
        target = source_relative
    if target == ".." or target.startswith("../") or target.startswith("/"):
        return target, False
    if _contains_symlink(root, target):
        return target, False
    candidate = root.joinpath(*Path(target).parts)
    if candidate.is_symlink() or not candidate.is_file():
        return target, False
    fragment = unquote(parsed.fragment)
    if fragment and not _anchor_exists(candidate, fragment):
        return f"{target}#{fragment}", False
    return f"{target}#{fragment}" if fragment else target, True


def resolve_declared_target(root: Path, source: Path, href: str) -> tuple[str, bool]:
    """Resolve front matter links with record and domain-relative compatibility."""
    target, resolved = resolve_local_target(root, source, href)
    if resolved or urlsplit(href).scheme or urlsplit(href).netloc:
        return target, resolved
    try:
        relative_source = source.relative_to(root)
    except ValueError:
        return target, resolved
    if len(relative_source.parts) < 3 or relative_source.parts[0] != "20_domains":
        return target, resolved
    domain_root = root.joinpath(*relative_source.parts[:2])
    domain_target, domain_resolved = resolve_local_target(root, domain_root / "INDEX.md", href)
    if domain_resolved:
        return domain_target, True
    return target, False


def _validate_record(root: Path, path: Path, frontmatter: FrontMatter) -> list[Finding]:
    findings: list[Finding] = []
    values = frontmatter.values
    line_for = frontmatter.lines
    record_path = relative_path(root, path)
    missing = sorted(RECORD_FIELDS - values.keys())
    for field in missing:
        findings.append(_path_finding(root, path, 1, "missing-field", f"falta el campo requerido: {field}"))
    for field in sorted(set(values) - RECORD_FIELDS):
        findings.append(
            _path_finding(root, path, line_for.get(field, 1), "unknown-field", f"campo no documentado: {field}")
        )

    def value(field: str) -> object:
        return values.get(field)

    record_id = value("id")
    if not isinstance(record_id, str) or not ID_RE.fullmatch(record_id) or record_id != path.stem:
        findings.append(_path_finding(root, path, line_for.get("id", 1), "invalid-id", f"id inválido o no coincide con el archivo: {record_id!r}"))
    record_type = value("type")
    if not isinstance(record_type, str) or record_type not in RECORD_TYPES:
        findings.append(_path_finding(root, path, line_for.get("type", 1), "invalid-type", f"type inválido: {record_type!r}"))
    status = value("status")
    if not isinstance(status, str) or status not in RECORD_STATUSES:
        findings.append(_path_finding(root, path, line_for.get("status", 1), "invalid-status", f"status inválido: {status!r}"))
    for field in ("created", "updated"):
        raw_date = value(field)
        if not isinstance(raw_date, str) or not DATE_RE.fullmatch(raw_date):
            findings.append(_path_finding(root, path, line_for.get(field, 1), "invalid-date", f"fecha inválida en {field}: {raw_date!r}"))
        else:
            try:
                date.fromisoformat(raw_date)
            except ValueError:
                findings.append(_path_finding(root, path, line_for.get(field, 1), "invalid-date", f"fecha inválida en {field}: {raw_date!r}"))
    if value("scope") != "project":
        findings.append(_path_finding(root, path, line_for.get("scope", 1), "invalid-scope", "scope debe ser project"))
    if not _scalar_string(value("author")):
        findings.append(_path_finding(root, path, line_for.get("author", 1), "invalid-author", "author no puede estar vacío"))
    for field in ("sources", "related"):
        if not isinstance(value(field), list) or not all(isinstance(item, str) for item in value(field)):
            findings.append(_path_finding(root, path, line_for.get(field, 1), "invalid-list", f"{field} debe ser una lista de cadenas"))
    for field in ("supersedes", "superseded_by"):
        if value(field) is not None and not _scalar_string(value(field)):
            findings.append(_path_finding(root, path, line_for.get(field, 1), "invalid-link", f"{field} debe ser null o una cadena"))

    for field in ("related", "supersedes", "superseded_by"):
        for href in _hrefs(value(field)):
            target, resolved = resolve_declared_target(root, path, href)
            if not resolved and not urlsplit(href).scheme:
                findings.append(
                    _path_finding(root, path, line_for.get(field, 1), "broken-relation", f"{field} no resuelve: {href} -> {target}")
                )
    return findings


def _index_entries(root: Path, index: Path) -> tuple[dict[str, list[str]], list[Finding]]:
    sections: dict[str, list[str]] = {"active": [], "retired": []}
    findings: list[Finding] = []
    try:
        lines = _read(index).splitlines()
    except VaultError as exc:
        return sections, [_path_finding(root, index, 1, "unreadable-index", str(exc))]
    section: str | None = None
    for line_number, line in enumerate(lines, 1):
        normalized = line.strip().casefold()
        if normalized.startswith("## "):
            title = normalized[3:].strip()
            if title in {"activos", "active"}:
                section = "active"
            elif title in {"retirados", "retired"}:
                section = "retired"
            else:
                section = None
            continue
        match = INDEX_LINK_RE.match(line)
        if match and section is not None:
            href = match.group(1)
            target, resolved = resolve_local_target(root, index, href)
            if not resolved:
                findings.append(_path_finding(root, index, line_number, "broken-index-link", f"índice no resuelve: {href} -> {target}"))
            else:
                sections[section].append(target.split("#", 1)[0])
    for name, entries in sections.items():
        if len(entries) != len(set(entries)):
            findings.append(_path_finding(root, index, 1, "duplicate-index-entry", f"el índice repite una entrada en {name}"))
    return sections, findings


def check_vault(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    required_directories = ("00_inbox", "10_areas", "20_domains", "30_resources", "40_archive", "50_daily", "60_exports", "_indexes", "_maps", "_templates")
    required_files = ("AGENTS.md", "_indexes/INDEX.md", "_indexes/action-log.md", "_maps/INDEX.md")
    for relative in required_directories:
        path = root / relative
        if not path.is_dir() or path.is_symlink():
            findings.append(_path_finding(root, path, 1, "missing-directory", f"falta directorio local: {relative}"))
    for relative in required_files:
        path = root / relative
        if not path.is_file() or path.is_symlink():
            findings.append(_path_finding(root, path, 1, "missing-file", f"falta archivo local: {relative}"))

    domains_root = root / "20_domains"
    if not domains_root.is_dir() or domains_root.is_symlink():
        return findings
    for domain in sorted(domains_root.iterdir(), key=lambda item: item.name):
        if domain.is_symlink() or not domain.is_dir():
            findings.append(_path_finding(root, domain, 1, "invalid-domain", f"dominio no es un directorio local: {domain.name}"))
            continue
        for relative in ("domain.yml", "AGENTS.md", "INDEX.md", "records", "resources"):
            path = domain / relative
            expected_directory = relative in {"records", "resources"}
            valid = path.is_dir() if expected_directory else path.is_file()
            if path.is_symlink() or not valid:
                findings.append(_path_finding(root, path, 1, "invalid-domain-package", f"falta paquete local: {relative} en {domain.name}"))
        records = domain / "records"
        if not records.is_dir() or records.is_symlink():
            continue
        record_paths = sorted((path for path in records.iterdir() if path.is_file() and not path.is_symlink() and path.suffix == ".md"), key=lambda item: item.name)
        for path in record_paths:
            try:
                frontmatter = parse_front_matter(_read(path))
            except (VaultError, FrontMatterError) as exc:
                line = getattr(exc, "line", 1)
                findings.append(_path_finding(root, path, line, "invalid-frontmatter", str(exc)))
                continue
            findings.extend(_validate_record(root, path, frontmatter))

        index = domain / "INDEX.md"
        if not index.is_file() or index.is_symlink():
            continue
        sections, index_findings = _index_entries(root, index)
        findings.extend(index_findings)
        indexed_active = set(sections["active"])
        indexed_retired = set(sections["retired"])
        for path in record_paths:
            try:
                frontmatter = parse_front_matter(_read(path))
                status = frontmatter.values.get("status")
            except (VaultError, FrontMatterError):
                continue
            record_relative = relative_path(root, path)
            expected = indexed_active if status == "active" else indexed_retired if status == "retired" else set()
            other = indexed_retired if status == "active" else indexed_active
            if record_relative not in expected:
                findings.append(_path_finding(root, index, 1, "missing-index-entry", f"registro no aparece en la sección correcta: {record_relative}"))
            if record_relative in other:
                findings.append(_path_finding(root, index, 1, "wrong-index-section", f"registro aparece en la sección incorrecta: {record_relative}"))
    return sorted(findings, key=lambda item: (item.path, item.line, item.code, item.message))


def find_matches(root: Path, pattern: str, ignore_case: bool = False) -> list[Match]:
    flags = re.IGNORECASE if ignore_case else 0
    try:
        expression = re.compile(pattern, flags)
    except re.error as exc:
        raise VaultError(f"regex inválida: {exc}") from exc
    matches: list[Match] = []
    for path in sorted(markdown_files(root), key=lambda item: relative_path(root, item)):
        text = _read(path)
        for line_number, line in enumerate(text.splitlines(), 1):
            if expression.search(line):
                matches.append(Match(relative_path(root, path), line_number, line))
    return matches


def _body_text(text: str) -> str:
    lines = text.splitlines()
    if lines and lines[0] == "---":
        for index in range(1, len(lines)):
            if lines[index] == "---":
                return "\n".join(lines[index + 1 :])
    return text


def relate_vault(root: Path, source_paths: set[str] | None = None) -> list[Relation]:
    relations: list[Relation] = []
    for path in sorted(markdown_files(root), key=lambda item: relative_path(root, item)):
        if source_paths is not None and relative_path(root, path) not in source_paths:
            continue
        text = _read(path)
        try:
            frontmatter = parse_front_matter(text)
        except FrontMatterError:
            frontmatter = None
        source = relative_path(root, path)
        for field in ("related", "supersedes", "superseded_by"):
            if frontmatter is None:
                break
            for href in _hrefs(frontmatter.values.get(field)):
                target, resolved = resolve_declared_target(root, path, href)
                if urlsplit(href).scheme or urlsplit(href).netloc:
                    continue
                relations.append(Relation(source, field, target, resolved))
        for href in MARKDOWN_LINK_RE.findall(_body_text(text)):
            parsed = urlsplit(href)
            if parsed.scheme or parsed.netloc:
                continue
            target, resolved = resolve_local_target(root, path, href)
            relations.append(Relation(source, "link", target, resolved))
    return sorted(relations, key=lambda item: (item.source, item.relation, item.target, item.resolved))
