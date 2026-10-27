"""Parser pequeño para el subconjunto de front matter documentado."""

from __future__ import annotations

from dataclasses import dataclass
import json
import re


KEY_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_-]*):(?:\s*(.*))?$")


class FrontMatterError(ValueError):
    """Indica que un documento no usa el subconjunto soportado."""

    def __init__(self, message: str, line: int = 1) -> None:
        super().__init__(message)
        self.line = line


@dataclass(frozen=True)
class FrontMatter:
    values: dict[str, object]
    lines: dict[str, int]
    body_start: int


def _scalar(value: str, line: int) -> object:
    value = value.strip()
    if value == "null":
        return None
    if value == "[]":
        return []
    if value.startswith("[") or value.endswith("]"):
        raise FrontMatterError("las listas deben usar líneas indentadas o []", line)
    if len(value) >= 2 and value[0] == value[-1] == '"':
        try:
            return json.loads(value)
        except json.JSONDecodeError as exc:
            raise FrontMatterError("cadena entrecomillada inválida", line) from exc
    if len(value) >= 2 and value[0] == value[-1] == "'":
        return value[1:-1].replace("''", "'")
    return value


def parse_front_matter(text: str) -> FrontMatter:
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        raise FrontMatterError("falta el delimitador inicial ---", 1)

    closing = None
    for index in range(1, len(lines)):
        if lines[index] == "---":
            closing = index
            break
    if closing is None:
        raise FrontMatterError("falta el delimitador final ---", len(lines) or 1)

    values: dict[str, object] = {}
    key_lines: dict[str, int] = {}
    active_list: str | None = None
    for index in range(1, closing):
        raw = lines[index]
        line_number = index + 1
        if not raw.strip():
            continue
        if raw.startswith("  - "):
            if active_list is None or not isinstance(values.get(active_list), list):
                raise FrontMatterError("elemento de lista sin una clave de lista", line_number)
            values[active_list].append(_scalar(raw[4:], line_number))
            continue
        if raw.startswith(" "):
            raise FrontMatterError("solo se admiten listas con indentación de dos espacios", line_number)
        match = KEY_RE.match(raw)
        if not match:
            raise FrontMatterError("línea de front matter inválida", line_number)
        key, raw_value = match.groups()
        if key in values:
            raise FrontMatterError(f"clave duplicada: {key}", line_number)
        key_lines[key] = line_number
        if raw_value is None or raw_value.strip() == "":
            values[key] = []
            active_list = key
        else:
            values[key] = _scalar(raw_value, line_number)
            active_list = None

    return FrontMatter(values=values, lines=key_lines, body_start=closing + 1)
