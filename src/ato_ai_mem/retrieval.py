"""Corpus estructural y retrieval léxico, transitorios y deterministas."""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
import fnmatch
import json
from pathlib import Path
import re

from .frontmatter import FrontMatterError, parse_front_matter
from .vault import (
    Finding,
    Relation,
    VaultError,
    _read,
    markdown_files,
    relative_path,
    relate_vault,
)


HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*#*\s*$")
TOKEN_RE = re.compile(r"\w+", re.UNICODE)


@dataclass(frozen=True)
class Chunk:
    id: str
    path: str
    line_start: int
    line_end: int
    heading_path: tuple[str, ...]
    text: str
    metadata: dict[str, object]


@dataclass(frozen=True)
class Corpus:
    documents: int
    chunks: list[Chunk]
    diagnostics: list[Finding]


@dataclass(frozen=True)
class RetrievedChunk:
    path: str
    line_start: int
    line_end: int
    heading_path: tuple[str, ...]
    snippet: str
    score: float
    matched_terms: tuple[str, ...]
    term_hits: int
    citation: str
    relations: tuple[Relation, ...]


def _matches_filters(path: str, includes: tuple[str, ...], excludes: tuple[str, ...]) -> bool:
    if excludes and any(fnmatch.fnmatchcase(path, pattern) for pattern in excludes):
        return False
    return not includes or any(fnmatch.fnmatchcase(path, pattern) for pattern in includes)


def _trimmed_range(lines: list[str], start: int, end: int) -> tuple[int, int] | None:
    while start <= end and not lines[start].strip():
        start += 1
    while end >= start and not lines[end].strip():
        end -= 1
    if start > end:
        return None
    return start, end


def _heading_title(raw: str) -> str:
    return raw.strip().rstrip("#").rstrip()


def _section_chunks(
    root: Path,
    path: Path,
    lines: list[str],
    body_start: int,
    metadata: dict[str, object],
) -> list[Chunk]:
    sections: list[tuple[int, int, tuple[str, ...]]] = []
    heading_stack: list[tuple[int, str]] = []
    section_start = body_start
    section_heading_path: tuple[str, ...] = ()

    for index in range(body_start, len(lines)):
        match = HEADING_RE.match(lines[index])
        if not match:
            continue
        section_range = _trimmed_range(lines, section_start, index - 1)
        if section_range is not None:
            sections.append((section_range[0], section_range[1], section_heading_path))
        level = len(match.group(1))
        title = _heading_title(match.group(2))
        while heading_stack and heading_stack[-1][0] >= level:
            heading_stack.pop()
        heading_stack.append((level, title))
        section_start = index
        section_heading_path = tuple(item[1] for item in heading_stack)

    section_range = _trimmed_range(lines, section_start, len(lines) - 1)
    if section_range is not None:
        sections.append((section_range[0], section_range[1], section_heading_path))

    relative = relative_path(root, path)
    return [
        Chunk(
            id=f"{relative}#L{start + 1}-L{end + 1}",
            path=relative,
            line_start=start + 1,
            line_end=end + 1,
            heading_path=heading_path,
            text="\n".join(lines[start : end + 1]),
            metadata=metadata,
        )
        for start, end, heading_path in sections
    ]


def build_corpus(
    root: Path,
    includes: tuple[str, ...] = (),
    excludes: tuple[str, ...] = (),
) -> Corpus:
    chunks: list[Chunk] = []
    diagnostics: list[Finding] = []
    documents = 0

    for path in sorted(markdown_files(root), key=lambda item: relative_path(root, item)):
        relative = relative_path(root, path)
        if not _matches_filters(relative, includes, excludes):
            continue
        documents += 1
        text = _read(path)
        lines = text.splitlines()
        metadata: dict[str, object] = {}
        body_start = 0
        if lines and lines[0] == "---":
            try:
                frontmatter = parse_front_matter(text)
            except FrontMatterError as exc:
                diagnostics.append(Finding(relative, exc.line, "invalid-frontmatter", str(exc)))
                body_start = 0
            else:
                metadata = frontmatter.values
                body_start = frontmatter.body_start
        chunks.extend(_section_chunks(root, path, lines, body_start, metadata))

    return Corpus(documents=documents, chunks=chunks, diagnostics=diagnostics)


def tokenize(value: str) -> list[str]:
    return TOKEN_RE.findall(value.casefold())


def _metadata_text(metadata: dict[str, object]) -> str:
    return json.dumps(metadata, ensure_ascii=False, sort_keys=True)


def _relation_dict(relation: Relation) -> dict[str, object]:
    return {
        "source": relation.source,
        "relation": relation.relation,
        "target": relation.target,
        "resolved": relation.resolved,
    }


def retrieve(
    root: Path,
    query: str,
    limit: int = 5,
    includes: tuple[str, ...] = (),
    excludes: tuple[str, ...] = (),
) -> tuple[Corpus, list[RetrievedChunk]]:
    if not query.strip():
        raise VaultError("--query no puede estar vacío")
    if not 1 <= limit <= 50:
        raise VaultError("--limit debe estar entre 1 y 50")

    corpus = build_corpus(root, includes, excludes)
    query_terms = tuple(dict.fromkeys(tokenize(query)))
    if not query_terms:
        raise VaultError("--query no contiene tokens recuperables")
    query_set = set(query_terms)
    relation_by_source: dict[str, list[Relation]] = {}
    for relation in relate_vault(root, {chunk.path for chunk in corpus.chunks}):
        relation_by_source.setdefault(relation.source, []).append(relation)

    ranked: list[tuple[tuple[float, int, int, str, int], RetrievedChunk]] = []
    for chunk in corpus.chunks:
        searchable = "\n".join((" ".join(chunk.heading_path), _metadata_text(chunk.metadata), chunk.text))
        counts = Counter(tokenize(searchable))
        matched_terms = tuple(sorted(query_set.intersection(counts)))
        if not matched_terms:
            continue
        term_hits = sum(counts[term] for term in matched_terms)
        coverage = len(matched_terms) / len(query_terms)
        heading_terms = set(tokenize(" ".join(chunk.heading_path)))
        heading_matches = len(query_set.intersection(heading_terms))
        result = RetrievedChunk(
            path=chunk.path,
            line_start=chunk.line_start,
            line_end=chunk.line_end,
            heading_path=chunk.heading_path,
            snippet=chunk.text,
            score=coverage,
            matched_terms=matched_terms,
            term_hits=term_hits,
            citation=f"{chunk.path}:L{chunk.line_start}-L{chunk.line_end}",
            relations=tuple(relation_by_source.get(chunk.path, ())),
        )
        ranked.append(((-coverage, -term_hits, -heading_matches, chunk.path, chunk.line_start), result))

    ranked.sort(key=lambda item: item[0])
    return corpus, [result for _, result in ranked[:limit]]


def chunk_dict(chunk: Chunk) -> dict[str, object]:
    return {
        "id": chunk.id,
        "path": chunk.path,
        "line_start": chunk.line_start,
        "line_end": chunk.line_end,
        "heading_path": list(chunk.heading_path),
        "text": chunk.text,
        "metadata": chunk.metadata,
    }


def retrieved_dict(result: RetrievedChunk) -> dict[str, object]:
    return {
        "path": result.path,
        "line_start": result.line_start,
        "line_end": result.line_end,
        "heading_path": list(result.heading_path),
        "snippet": result.snippet,
        "score": result.score,
        "matched_terms": list(result.matched_terms),
        "term_hits": result.term_hits,
        "citation": result.citation,
        "relations": [_relation_dict(relation) for relation in result.relations],
    }
