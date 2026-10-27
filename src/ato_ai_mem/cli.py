"""Interfaz de línea de comandos de ato-mem."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from .retrieval import build_corpus, chunk_dict, retrieve, retrieved_dict
from .vault import Finding, Match, Relation, VaultError, check_vault, find_matches, relate_vault, validate_root


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ato-mem", description="Análisis determinista de vaults formato 3")
    commands = parser.add_subparsers(dest="command", required=True)
    for name, help_text in (
        ("check", "audita documentos e índices sin modificar la vault"),
        ("find", "busca una expresión regular en archivos Markdown"),
        ("relate", "extrae relaciones Markdown declaradas"),
    ):
        command = commands.add_parser(name, help=help_text)
        command.add_argument("--vault", required=True, type=Path, help="ruta de la vault formato 3")
        command.add_argument("--format", choices=("text", "json"), default="text")
        if name == "find":
            command.add_argument("--pattern", required=True, help="expresión regular Python")
            command.add_argument("--ignore-case", action="store_true", help="ignora mayúsculas y minúsculas")
    for name, help_text in (
        ("build", "construye un corpus estructural transitorio"),
        ("retrieve", "recupera chunks mediante ranking léxico"),
    ):
        command = commands.add_parser(name, help=help_text)
        command.add_argument("--vault", required=True, type=Path, help="ruta de la vault formato 3")
        command.add_argument("--format", choices=("text", "json"), default="json")
        command.add_argument("--include", action="append", default=[], metavar="GLOB", help="incluye una ruta relativa que coincida con GLOB")
        command.add_argument("--exclude", action="append", default=[], metavar="GLOB", help="excluye una ruta relativa que coincida con GLOB")
        if name == "retrieve":
            command.add_argument("--query", required=True, help="consulta textual")
            command.add_argument("--limit", type=int, default=5, help="máximo de resultados (1-50)")
    return parser


def _json_item(item: Finding | Match | Relation | dict[str, object]) -> dict[str, object]:
    if isinstance(item, dict):
        return item
    if isinstance(item, Finding):
        return {"path": item.path, "line": item.line, "code": item.code, "message": item.message}
    if isinstance(item, Match):
        return {"path": item.path, "line": item.line, "snippet": item.snippet}
    return {"source": item.source, "relation": item.relation, "target": item.target, "resolved": item.resolved}


def _emit_json(
    command: str,
    status: str,
    summary: dict[str, object],
    items: list[object],
    extra: dict[str, object] | None = None,
) -> None:
    payload = {
        "schema": 1,
        "command": command,
        "status": status,
        "summary": summary,
        "items": [_json_item(item) for item in items],
    }
    if extra:
        payload.update(extra)
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True))


def _emit_text(command: str, items: list[object], summary: dict[str, object]) -> None:
    if command == "check":
        if not items:
            print("check: ok")
            return
        for item in items:
            finding = item
            assert isinstance(finding, Finding)
            print(f"{finding.path}:{finding.line}: [{finding.code}] {finding.message}")
        return
    if command == "find":
        if not items:
            print("find: no matches")
            return
        for item in items:
            match = item
            assert isinstance(match, Match)
            print(f"{match.path}:{match.line}: {match.snippet}")
        return
    if command == "build":
        if not items:
            print("build: no chunks")
            return
        for item in items:
            chunk = item
            print(f"{chunk['id']}")
        return
    if command == "retrieve":
        if not items:
            print("retrieve: no matches")
            return
        for item in items:
            print(f"{item['citation']}: score={item['score']:.4f} terms={','.join(item['matched_terms'])}")
        return
    if not items:
        print("relate: no declared local relations")
        return
    for item in items:
        relation = item
        assert isinstance(relation, Relation)
        state = "resolved" if relation.resolved else "unresolved"
        print(f"{relation.source} --{relation.relation}--> {relation.target} [{state}]")


def _emit(command: str, output_format: str, items: list[object], summary: dict[str, object], exit_code: int) -> int:
    status = "ok" if exit_code == 0 else "findings"
    if output_format == "json":
        _emit_json(command, status, summary, items)
    else:
        _emit_text(command, items, summary)
    return exit_code


def _emit_error(command: str | None, output_format: str, message: str) -> int:
    if output_format == "json":
        _emit_json(command or "unknown", "error", {"errors": 1}, [{"path": "", "line": 0, "code": "error", "message": message}])
    else:
        print(f"error: {message}", file=sys.stderr)
    return 2


def main(argv: list[str] | None = None) -> int:
    parser = _parser()
    try:
        args = parser.parse_args(argv)
    except SystemExit as exc:
        return int(exc.code)

    try:
        root = validate_root(args.vault)
        if args.command == "check":
            items = check_vault(root)
            return _emit("check", args.format, items, {"findings": len(items)}, 1 if items else 0)
        if args.command == "find":
            items = find_matches(root, args.pattern, args.ignore_case)
            return _emit("find", args.format, items, {"matches": len(items)}, 1 if not items else 0)
        if args.command == "relate":
            items = relate_vault(root)
            unresolved = sum(1 for item in items if not item.resolved)
            summary = {"relations": len(items), "unresolved": unresolved}
            return _emit("relate", args.format, items, summary, 1 if unresolved else 0)
        if args.command == "build":
            corpus = build_corpus(root, tuple(args.include), tuple(args.exclude))
            items = [chunk_dict(chunk) for chunk in corpus.chunks]
            diagnostics = [_json_item(item) for item in corpus.diagnostics]
            summary = {
                "documents": corpus.documents,
                "chunks": len(corpus.chunks),
                "diagnostics": len(corpus.diagnostics),
            }
            status = "findings" if corpus.diagnostics else "ok"
            if args.format == "json":
                _emit_json("build", status, summary, items, {"diagnostics": diagnostics})
            else:
                _emit_text("build", items, summary)
                for diagnostic in corpus.diagnostics:
                    print(f"{diagnostic['path']}:{diagnostic['line']}: [{diagnostic['code']}] {diagnostic['message']}")
            return 1 if corpus.diagnostics else 0
        if args.command == "retrieve":
            corpus, results = retrieve(
                root,
                args.query,
                args.limit,
                tuple(args.include),
                tuple(args.exclude),
            )
            items = [retrieved_dict(result) for result in results]
            diagnostics = [_json_item(item) for item in corpus.diagnostics]
            summary = {
                "documents": corpus.documents,
                "chunks": len(corpus.chunks),
                "diagnostics": len(corpus.diagnostics),
                "results": len(results),
            }
            exit_code = 1 if corpus.diagnostics or not results else 0
            status = "findings" if exit_code else "ok"
            if args.format == "json":
                _emit_json("retrieve", status, summary, items, {"diagnostics": diagnostics})
            else:
                _emit_text("retrieve", items, summary)
                for diagnostic in corpus.diagnostics:
                    print(f"{diagnostic['path']}:{diagnostic['line']}: [{diagnostic['code']}] {diagnostic['message']}")
            return exit_code
        return _emit_error(args.command, args.format, "comando desconocido")
    except (VaultError, OSError) as exc:
        return _emit_error(getattr(args, "command", None), getattr(args, "format", "text"), str(exc))
