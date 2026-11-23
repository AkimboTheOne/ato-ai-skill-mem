#!/usr/bin/env python3
"""Búsqueda documental local y de solo lectura."""
import argparse
import json
import os
from pathlib import Path
import re
import stat
import sys
import unicodedata

ROOT = Path(__file__).resolve().parent.parent
WIKI = ROOT / 'wiki'

def is_redirect(path):
    """Detecta enlaces simbólicos y otros reparse points, incluidos junctions Windows."""
    try:
        info = path.lstat()
    except FileNotFoundError:
        return False
    return stat.S_ISLNK(info.st_mode) or bool(getattr(info, 'st_file_attributes', 0) & 0x400)

def normalize(value):
    return ''.join(c for c in unicodedata.normalize('NFKD', value.casefold()) if not unicodedata.combining(c))

def tokens(value):
    return set(re.findall(r'[^\W_]+', normalize(value), re.UNICODE))

def files(scope, domain):
    if is_redirect(WIKI) or not WIKI.is_dir(): raise ValueError('wiki ausente o no local')
    if domain:
        if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,62}', domain): raise ValueError('id de dominio inválido')
        base = WIKI / '20_domains' / domain
        for part in (WIKI / '20_domains', base):
            if is_redirect(part) or not part.is_dir(): raise ValueError('dominio ausente o no local')
    else:
        base = WIKI
    def traversal_error(error):
        raise error
    for folder, dirs, names in os.walk(base, followlinks=False, onerror=traversal_error):
        dirs.sort(); names.sort()
        for name in dirs + names:
            if is_redirect(Path(folder) / name): raise ValueError('se rechazan enlaces simbólicos y junctions: ' + str((Path(folder) / name).relative_to(WIKI)))
        for name in names:
            path = Path(folder) / name
            if path.suffix.lower() not in ('.md', '.yml', '.yaml'): continue
            is_index = name == 'INDEX.md' or '_indexes' in path.relative_to(WIKI).parts
            if scope == 'indexes' and not is_index: continue
            yield path

def lines_for(path, scope):
    lines = path.read_text(encoding='utf-8').splitlines()
    if scope != 'headers': return list(enumerate(lines, 1))
    in_front = bool(lines and lines[0] == '---')
    selected = []
    for number, line in enumerate(lines, 1):
        if in_front:
            selected.append((number, line))
            if number > 1 and line == '---': in_front = False
        elif path.suffix.lower() in ('.yml', '.yaml') or re.match(r'^#{1,6}\s+', line): selected.append((number, line))
    return selected

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('query')
    parser.add_argument('--mode', choices=('text', 'regex', 'language'), default='text')
    parser.add_argument('--scope', choices=('content', 'indexes', 'headers'), default='content')
    parser.add_argument('--domain')
    parser.add_argument('--limit', type=int, default=20)
    args = parser.parse_args()
    if not args.query.strip() or args.limit < 1 or args.limit > 100: raise ValueError('consulta vacía o límite fuera de 1..100')
    pattern = re.compile(args.query, re.IGNORECASE) if args.mode == 'regex' else None
    terms = tokens(args.query)
    if args.mode == 'language' and not terms: raise ValueError('la consulta no contiene términos')
    results = []
    for path in files(args.scope, args.domain):
        selected = lines_for(path, args.scope)
        hits = []
        seen_terms = set()
        for number, line in selected:
            if args.mode == 'regex': matched = bool(pattern.search(line))
            elif args.mode == 'text': matched = normalize(args.query) in normalize(line)
            else:
                common = terms & tokens(line); seen_terms.update(common); matched = bool(common)
            if matched: hits.append({'line': number, 'text': line[:500]})
        if hits:
            results.append({'path': path.relative_to(WIKI).as_posix(), 'score': len(seen_terms) if args.mode == 'language' else len(hits), 'matches': hits[:5]})
    results.sort(key=lambda item: (-item['score'], item['path']))
    print(json.dumps({'mode': args.mode, 'scope': args.scope, 'results': results[:args.limit]}, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    try: main()
    except (ValueError, OSError, UnicodeError, re.error) as exc:
        print('error: ' + str(exc), file=sys.stderr); sys.exit(2)
