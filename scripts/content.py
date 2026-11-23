#!/usr/bin/env python3
"""Operaciones explícitas de contenido sobre la vault de esta instalación."""
import argparse
import datetime as dt
import hashlib
import json
import socket
import os
from pathlib import Path, PurePosixPath
import re
import stat
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
VAULT = ROOT / 'vault'
SECTIONS = {'00_inbox', '10_areas', '20_domains', '30_resources', '40_archive', '50_daily', '60_exports', '_maps'}
PROTECTED = {'AGENTS.md', 'INDEX.md', 'domain.yml', 'action-log.md'}
RECORD = re.compile(r'^\d{4}-\d{2}-\d{2}--[a-z0-9]+(?:-[a-z0-9]+)*\.md$')
DOCUMENT = re.compile(r'^[a-z0-9]+(?:-[a-z0-9]+)*\.md$')
DAILY = re.compile(r'^\d{4}-\d{2}-\d{2}\.md$')
RESERVED = re.compile(r'^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])$', re.IGNORECASE)
LINK = re.compile(r'!?\[[^]]*\]\(([^)]+)\)')
TEMPLATES = {**{name: ROOT / 'templates/records' / (name + '.md') for name in ('decision', 'convention', 'lesson', 'project-context')}, **{name: VAULT / '_templates' / (name + '.md') for name in ('area', 'daily', 'pending-decision', 'export', 'resource', 'map', 'archive')}}
SNAPSHOTS = {}
LOCK_PATH = VAULT / '.local-mem.lock'
LOCK_STREAM = None
PUBLICATION_STARTED = False
ROLLBACK_FAILED = False
PLACEHOLDER = re.compile(r'YYYY-MM-DD|AREA_TITLE|SOURCE_PATH|DOCUMENT_ID|AUTHOR|human \| agent-name|Título de (?:la|el) (?:decisión|convención|lección|contexto)')

class OperationError(Exception):
    pass

def fail(message):
    raise OperationError(message)

def path_for(value, *, exists=False, allow_missing_parent=False):
    if not value or '\\' in value or value.startswith('/'):
        fail('ruta inválida')
    parts = PurePosixPath(value).parts
    if not parts or any(x in ('.', '..') for x in value.split('/')) or parts[0] not in SECTIONS:
        fail('ruta fuera del contenido permitido')
    if Path(value).suffix != '.md' or parts[-1] in PROTECTED:
        fail('destino reservado o no Markdown')
    current = VAULT
    if current.is_symlink() or not current.is_dir():
        fail('vault ausente o no local')
    for part in parts:
        current = current / part
        if current.is_symlink():
            fail('se rechazan enlaces simbólicos')
    if not current.parent.is_dir() and not allow_missing_parent:
        fail('directorio padre inexistente')
    if exists and not current.is_file():
        fail('documento inexistente o no regular')
    return current

def read_path(value):
    if not value or '\\' in value or value.startswith('/') or any(part in ('', '.', '..') for part in value.split('/')):
        fail('ruta inválida')
    if VAULT.is_symlink() or not VAULT.is_dir(): fail('vault ausente o no local')
    current = VAULT
    for part in PurePosixPath(value).parts:
        current = current / part
        if current.is_symlink(): fail('se rechazan enlaces simbólicos')
    if not current.is_file(): fail('archivo inexistente o no regular')
    return current

def validate_new_name(path):
    """Valida solo el nombre nuevo; las rutas heredadas permanecen accesibles."""
    parts = path.relative_to(VAULT).parts
    name = parts[-1]
    is_record = len(parts) == 4 and parts[0] == '20_domains' and parts[2] == 'records'
    if is_record:
        if not RECORD.fullmatch(name): fail('nombre de registro inválido: usa YYYY-MM-DD--slug.md')
        date = name[:10]
    elif parts[0] == '50_daily':
        if not DAILY.fullmatch(name): fail('nombre de diario inválido: usa YYYY-MM-DD.md')
        date = name[:-3]
    else:
        if not DOCUMENT.fullmatch(name): fail('nombre inválido: usa minúsculas, dígitos y guiones en un archivo .md')
        date = None
    if RESERVED.fullmatch(path.stem): fail('nombre reservado en Windows')
    if date:
        try:
            if dt.date.fromisoformat(date).isoformat() != date: raise ValueError()
        except ValueError: fail('fecha inválida en el nombre')

def record_info(path):
    parts = path.relative_to(VAULT).parts
    if len(parts) >= 4 and parts[0] == '20_domains' and parts[2] == 'records':
        if len(parts) != 4: fail('los registros deben estar directamente en records/')
        if not RECORD.fullmatch(parts[3]):
            fail('nombre de registro inválido')
        domain = VAULT / '20_domains' / parts[1]
        meta = domain / 'domain.yml'
        if meta.is_symlink() or not meta.is_file() or not re.search(r'(?m)^id:\s*' + re.escape(parts[1]) + r'\s*$', meta.read_text(encoding='utf-8')):
            fail('identidad de dominio inválida')
        return domain
    return None

def frontmatter(content):
    """Lee solo escalares y listas simples; rechaza construcciones YAML ambiguas."""
    match = re.match(r'\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)', content, re.S)
    if not match: fail('falta front matter del documento')
    fields = {}
    key = None
    def scalar(value):
        if not value: fail('valor vacío en front matter')
        if value.startswith('"'):
            try:
                parsed = json.loads(value)
                if not isinstance(parsed, str): raise ValueError()
            except ValueError: fail('valor entre comillas no compatible')
        elif value.startswith("'"):
            if len(value) < 2 or not value.endswith("'") or "'" in value[1:-1].replace("''", ''):
                fail('valor entre comillas no compatible')
        elif value not in ('[]', '{}'):
            if value[0] in '[]{}!&*|>@`%\"\'' or ': ' in value or ' #' in value or value.endswith(':'):
                fail('valor YAML no compatible: ' + value)
        return value
    for line in match.group(1).splitlines():
        if not line.strip() or line.lstrip().startswith('#'): continue
        found = re.fullmatch(r'([a-z_]+):[ \t]*(.*)', line)
        if found:
            key, value = found.groups()
            if key in fields: fail('metadato duplicado: ' + key)
            fields[key] = scalar(value) if value else ''
        elif line.startswith('  - ') and key is not None:
            if fields[key] and not fields[key].startswith('\n  - '): fail('lista de metadatos no compatible')
            fields[key] += '\n  - ' + scalar(line[4:])
        else: fail('front matter no compatible: ' + line)
    if any(not value for value in fields.values()): fail('metadatos vacíos')
    return fields

def metadata(content):
    data = frontmatter(content)
    required = {'id', 'type', 'status', 'created', 'updated', 'scope', 'author', 'sources', 'related', 'supersedes', 'superseded_by'}
    if not required.issubset(data): fail('metadatos incompletos')
    return data

def validate_document(content):
    fields = frontmatter(content)
    for key in ('id', 'type', 'status', 'created', 'updated', 'author', 'sources'):
        if not fields.get(key): fail('metadato requerido: ' + key)
    for key in ('created', 'updated'):
        try: dt.date.fromisoformat(fields[key])
        except ValueError: fail('fecha inválida: ' + key)
    if fields['updated'] < fields['created']: fail('updated precede a created')
    return fields

def validate_record(path, content):
    data = metadata(content)
    if data['id'] != path.stem or data['status'] not in ('active', 'retired'):
        fail('identidad o estado de registro inválido')
    for key in ('created', 'updated'):
        try: dt.date.fromisoformat(data[key])
        except ValueError: fail('fecha inválida: ' + key)
    if data['created'] != path.name[:10]: fail('la fecha de creación no coincide con el nombre')
    if data['updated'] < data['created']: fail('updated precede a created')
    return data

def snapshot(path):
    if path not in SNAPSHOTS:
        if path.is_symlink(): fail('se rechazan enlaces simbólicos')
        if path.exists():
            data = path.read_bytes()
            SNAPSHOTS[path] = (data, stat.S_IMODE(path.stat().st_mode))
        else:
            SNAPSHOTS[path] = None
    return SNAPSHOTS[path]

def read_text(path):
    value = snapshot(path)
    if value is None: fail('archivo inexistente: ' + str(path))
    return value[0].decode('utf-8')

def validate_legacy_pending(path, content):
    parts = path.relative_to(VAULT).parts
    if parts[:2] != ('00_inbox', 'decisions-pending'): return None
    match = re.match(r'\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)', content, re.S)
    if not match: return None
    fields = frontmatter(content)
    if set(fields) != {'id', 'status', 'source', 'proposed_domain', 'created'}: return None
    if not all(fields.values()) or fields['status'] not in ('pending', 'retired'): return None
    try: dt.date.fromisoformat(fields['created'])
    except ValueError: return None
    return fields

def regular(path):
    if path.is_symlink() or not path.is_file(): fail('archivo auxiliar ausente o no local: ' + str(path))
    value = snapshot(path)
    return value[0]

def prepare_template(name, path):
    data = regular(path)
    if not path.is_relative_to(VAULT): return data
    text = data.decode('utf-8')
    canonical = (ROOT / 'templates/vault-layout' / (name + '.md')).read_text(encoding='utf-8')
    canonical_match = re.match(r'\A---\r?\n(.*?)\r?\n---\r?\n', canonical, re.S)
    if not canonical_match: fail('plantilla canónica inválida')
    baseline = canonical_match.group(1).splitlines()
    existing = re.match(r'\A---\r?\n(.*?)\r?\n---(?=\r?\n|$)', text, re.S)
    newline = '\r\n' if '\r\n' in text else '\n'
    if not existing:
        return ('---' + newline + newline.join(baseline) + newline + '---' + newline + newline + text).encode('utf-8')
    fields = re.findall(r'(?m)^([a-z_]+):', existing.group(1))
    if len(fields) != len(set(fields)): fail('metadato duplicado en plantilla')
    missing = [line for line in baseline if line.split(':', 1)[0] not in fields]
    if not missing: return data
    return (text[:existing.end(1)] + newline + newline.join(missing) + text[existing.end(1):]).encode('utf-8')

def manual_plan(operation, source, destination):
    """Inventa archivos para revisión humana sin interpretar referencias."""
    def traversal_error(error):
        raise error
    documents = []
    for base, dirs, files in os.walk(VAULT, followlinks=False, onerror=traversal_error):
        dirs.sort(); files.sort()
        for name in dirs + files:
            path = Path(base) / name
            if path.is_symlink(): fail('symlink en la vault: ' + str(path.relative_to(VAULT)))
        for name in files:
            path = Path(base) / name
            if path == LOCK_PATH: continue
            if not path.is_file(): fail('archivo no regular: ' + str(path.relative_to(VAULT)))
            digest = hashlib.sha256()
            with path.open('rb') as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(chunk)
            documents.append({'path': path.relative_to(VAULT).as_posix(), 'sha256': digest.hexdigest()})
    return {'operation': operation, 'source': source.relative_to(VAULT).as_posix(),
            'destination': destination.relative_to(VAULT).as_posix(),
            'documents': documents, 'review_required': True}

def index_section(text, line, retired=False):
    pattern = r'(?im)^## (?:retirados|históricos retirados)\s*$' if retired else r'(?im)^## activos?\s*$'
    matches = list(re.finditer(pattern, text))
    if len(matches) != 1: fail('sección del índice ausente o ambigua')
    end = text.find('\n', matches[0].end())
    if end < 0: end = len(text)
    newline = '\r\n' if '\r\n' in text else '\n'
    if end > 0 and text[end - 1:end] == '\r': end -= 1
    return text[:end] + newline + newline + line + text[end:]

def publish(changes, snapshots=None, modes=None):
    global PUBLICATION_STARTED, ROLLBACK_FAILED
    original = snapshots if snapshots is not None else {p: snapshot(p) for p in changes}
    modes = modes or {}
    applied = []
    cleanup_errors = []
    if LOCK_STREAM is not None:
        LOCK_STREAM.write(json.dumps({'stage': 'publish', 'paths': [str(p.relative_to(VAULT)) for p in changes]}, ensure_ascii=False) + '\n')
        LOCK_STREAM.flush(); os.fsync(LOCK_STREAM.fileno())
    PUBLICATION_STARTED = True
    try:
        for path, data in changes.items():
            expected = original[path]
            if path.is_symlink(): raise OSError('conflicto: enlace simbólico: ' + str(path))
            current = (path.read_bytes(), stat.S_IMODE(path.stat().st_mode)) if path.exists() else None
            if current != expected: raise OSError('conflicto: archivo modificado: ' + str(path))
            if data is None:
                path.unlink()
                applied.append((path, data))
            else:
                fd, name = tempfile.mkstemp(prefix='.content-', dir=path.parent)
                try:
                    with os.fdopen(fd, 'wb') as stream: stream.write(data)
                    mode = expected[1] if expected else modes.get(path)
                    if mode is not None: os.chmod(name, mode)
                    if expected is None:
                        os.link(name, path)
                        applied.append((path, data))
                        os.unlink(name)
                    else:
                        os.replace(name, path)
                        applied.append((path, data))
                finally:
                    if os.path.exists(name):
                        try: os.unlink(name)
                        except OSError as cleanup_error:
                            cleanup_errors.append(str(cleanup_error))
                            raise
        for path, data in applied:
            actual = path.read_bytes() if path.exists() else None
            if actual != data: raise OSError('no se pudo verificar: ' + str(path))
    except Exception as exc:
        errors = list(cleanup_errors)
        for path, published in reversed(applied):
            try:
                present = path.read_bytes() if path.exists() else None
                if present != published: raise OSError('archivo modificado durante reversión: ' + str(path))
                previous = original[path]
                if previous is None: path.unlink()
                else:
                    path.write_bytes(previous[0]); os.chmod(path, previous[1])
            except Exception as rollback: errors.append(str(rollback))
        ROLLBACK_FAILED = bool(errors)
        fail('falló la operación: ' + str(exc) + ('; falló la reversión: ' + '; '.join(errors) if errors else '; cambios revertidos'))

def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['template', 'read', 'create', 'update', 'plan-move', 'plan-retire', 'move', 'retire'])
    parser.add_argument('--path')
    parser.add_argument('--type', choices=sorted(TEMPLATES))
    parser.add_argument('--input')
    parser.add_argument('--destination')
    return parser.parse_args()

def main(args):
    if args.operation == 'template':
        if not args.type or args.path or args.input or args.destination: fail('template requiere solo --type')
        template = TEMPLATES[args.type]
        if template.is_relative_to(VAULT): template = read_path(template.relative_to(VAULT).as_posix())
        sys.stdout.buffer.write(prepare_template(args.type, template)); return
    if args.type or not args.path: fail('se requiere --path y --type solo se usa con template')
    if (args.operation in ('create', 'update')) != bool(args.input) or (args.operation in ('move', 'plan-move')) != bool(args.destination):
        fail('argumentos incompatibles con la operación')
    if args.operation == 'read':
        sys.stdout.buffer.write(read_path(args.path).read_bytes()); return
    if args.operation in ('move', 'retire'):
        fail('operación manual: usa plan-move o plan-retire y revisa las referencias bajo el lock')
    source = path_for(args.path, exists=args.operation != 'create')
    if args.operation in ('plan-move', 'plan-retire'):
        if args.operation == 'plan-move':
            destination = path_for(args.destination)
            validate_new_name(destination)
            if source.relative_to(VAULT).parts[0] != destination.relative_to(VAULT).parts[0]: fail('el movimiento debe permanecer en la misma sección')
            if record_info(source): fail('un registro conserva su identidad y dominio; usa plan-retire')
        else:
            destination = path_for('40_archive/' + args.path, allow_missing_parent=True)
        if destination.exists() or destination.is_symlink(): fail('destino existente')
        print(json.dumps(manual_plan(args.operation[5:], source, destination), ensure_ascii=False, indent=2))
        return
    domain = record_info(source)
    changes = {}
    modes = {}
    if args.operation in ('create', 'update'):
        if args.operation == 'create':
            validate_new_name(source)
            if snapshot(source) is not None: fail('destino existente')
        content = Path(args.input).read_bytes().decode('utf-8')
        if args.operation == 'create':
            if PLACEHOLDER.search(content): fail('la plantilla contiene marcadores sin completar')
            validate_document(content)
        if args.operation == 'update':
            old_content = read_text(source)
            if old_content.startswith('---\n') or old_content.startswith('---\r\n'):
                legacy = validate_legacy_pending(source, old_content)
                if legacy is not None:
                    new_fields = validate_legacy_pending(source, content) or validate_document(content)
                    for key in ('id', 'created', 'source', 'proposed_domain'):
                        if legacy[key] != new_fields.get(key): fail('metadato protegido: ' + key)
                else:
                    old_fields = frontmatter(old_content)
                    required = {'id', 'type', 'status', 'created', 'updated', 'author', 'sources'}
                    new_fields = validate_document(content) if required.issubset(old_fields) else frontmatter(content)
                    for key, value in old_fields.items():
                        if key not in ('updated', 'status') and new_fields.get(key) != value:
                            fail('metadato protegido: ' + key)
            if not set(LINK.findall(old_content)).issubset(set(LINK.findall(content))):
                fail('la actualización elimina enlaces existentes')
        if domain:
            new = validate_record(source, content)
            if args.operation == 'update':
                old = validate_record(source, old_content)
                for key in ('id', 'status', 'created', 'author', 'sources', 'related', 'supersedes', 'superseded_by'):
                    if old[key] != new[key]: fail('metadato protegido: ' + key)
            else:
                if new['status'] != 'active': fail('un registro nuevo debe estar activo')
                index = domain / 'INDEX.md'
                index_bytes = regular(index)
                line = '- [' + source.stem + '](records/' + source.name + ')'
                changes[index] = index_section(index_bytes.decode('utf-8'), line).encode('utf-8')
        changes[source] = content.encode('utf-8')
    log = read_path('_indexes/action-log.md')
    log_bytes = regular(log)
    timestamp = dt.datetime.now(dt.timezone.utc).isoformat(timespec='seconds')
    entry = f'{timestamp} | {args.operation} | {json.dumps(args.path, ensure_ascii=False)} | operator\n'
    changes[log] = log_bytes + (b'\n' if log_bytes and not log_bytes.endswith(b'\n') else b'') + entry.encode('utf-8')
    if LOCK_STREAM is not None:
        LOCK_STREAM.write(json.dumps({'stage': 'prepared', 'paths': [str(p.relative_to(VAULT)) for p in changes]}, ensure_ascii=False) + '\n')
        LOCK_STREAM.flush(); os.fsync(LOCK_STREAM.fileno())
    created_dirs = []
    try:
        for path in changes:
            missing = []
            parent = path.parent
            while not parent.exists():
                missing.append(parent); parent = parent.parent
            for directory in reversed(missing):
                directory.mkdir(); created_dirs.append(directory)
        for path in changes: snapshot(path)
        publish(changes, {path: SNAPSHOTS[path] for path in changes}, modes)
    except Exception:
        for directory in reversed(created_dirs):
            try: directory.rmdir()
            except OSError: pass
        raise
    print('operación completada: ' + args.operation)

def run_locked(args):
    global LOCK_STREAM
    if VAULT.is_symlink() or not VAULT.is_dir(): fail('vault ausente o no local')
    try:
        fd = os.open(LOCK_PATH, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        fail('vault bloqueada; revisa .local-mem.lock antes de continuar')
    release = False
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            LOCK_STREAM = stream
            stream.write(json.dumps({'operation': args.operation, 'pid': os.getpid(), 'host': socket.gethostname(), 'stage': 'prepare', 'arguments': sys.argv[1:]}, ensure_ascii=False) + '\n')
            stream.flush(); os.fsync(stream.fileno())
            try:
                main(args)
                release = True
            except (OperationError, OSError, UnicodeError):
                if not PUBLICATION_STARTED or (isinstance(sys.exc_info()[1], OperationError) and not ROLLBACK_FAILED):
                    release = True
                raise
    finally:
        LOCK_STREAM = None
        if release: LOCK_PATH.unlink()

if __name__ == '__main__':
    try:
        args = parse_args()
        if args.operation in ('create', 'update'):
            run_locked(args)
        else:
            main(args)
    except (OperationError, OSError, UnicodeError) as exc:
        print('error: ' + str(exc), file=sys.stderr); sys.exit(1)
