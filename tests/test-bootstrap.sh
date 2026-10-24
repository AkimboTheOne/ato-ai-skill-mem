#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT

PROJECT=$TEMP_ROOT/consumer
LEGACY=$TEMP_ROOT/legacy
mkdir -p "$PROJECT"
printf '%s\n' 'before' > "$PROJECT/AGENTS.md"
cp "$PROJECT/AGENTS.md" "$PROJECT/AGENTS.before"

"$ROOT/scripts/bootstrap.sh" --target "$PROJECT"

[ -L "$PROJECT/mem/SKILL.md" ]
[ "$(readlink "$PROJECT/mem/SKILL.md")" = "$ROOT/SKILL.md" ]
[ -L "$PROJECT/mem/references" ]
[ -L "$PROJECT/mem/templates" ]
[ -f "$PROJECT/mem/workspace/INDEX.md" ]
[ -f "$PROJECT/mem/workspace/.ato-ai-skill-mem-version.yml" ]
[ "$(sed -n 's/^workspace_format: *//p' "$PROJECT/mem/workspace/.ato-ai-skill-mem-version.yml")" = '1' ]
[ -d "$PROJECT/mem/workspace/records" ]
cmp -s "$PROJECT/AGENTS.md" "$PROJECT/AGENTS.before"

mkdir -p "$LEGACY/mem/workspace/records"
printf '%s\n' '# Legacy memory' > "$LEGACY/mem/workspace/INDEX.md"
"$ROOT/scripts/bootstrap.sh" --target "$LEGACY" --status | grep -F -x 'workspace.data_compatibility: compatible' >/dev/null
"$ROOT/scripts/bootstrap.sh" --target "$LEGACY" --status | grep -F -x 'workspace.state: legacy-compatible' >/dev/null

"$ROOT/scripts/bootstrap.sh" --target "$PROJECT" --status | grep -F -x 'workspace.state: aligned' >/dev/null
printf '%s\n' 'skill_version: 0.0.0' > "$PROJECT/mem/workspace/.ato-ai-skill-mem-version.yml"
"$ROOT/scripts/bootstrap.sh" --target "$PROJECT" --status | grep -F -x 'workspace.state: compatible-update-available' >/dev/null
if "$ROOT/scripts/bootstrap.sh" --target "$PROJECT" --update-workspace >/dev/null 2>&1; then
  printf '%s\n' 'la actualización del workspace aceptó una fuente sin release' >&2
  exit 1
fi
printf '%s\n' 'workspace_format: 2' > "$PROJECT/mem/workspace/.ato-ai-skill-mem-version.yml"
"$ROOT/scripts/bootstrap.sh" --target "$PROJECT" --status | grep -F -x 'workspace.data_compatibility: migration-required' >/dev/null
"$ROOT/scripts/bootstrap.sh" --target "$PROJECT" --status | grep -F -x 'workspace.state: migration-required' >/dev/null

printf '%s\n' '# Local memory' > "$PROJECT/mem/workspace/INDEX.md"
"$ROOT/scripts/bootstrap.sh" --target "$PROJECT"
grep -F -x '# Local memory' "$PROJECT/mem/workspace/INDEX.md" >/dev/null
cmp -s "$PROJECT/AGENTS.md" "$PROJECT/AGENTS.before"

CONFLICT=$TEMP_ROOT/conflict
mkdir -p "$CONFLICT/mem/references"
if "$ROOT/scripts/bootstrap.sh" --target "$CONFLICT" >/dev/null 2>&1; then
  printf '%s\n' 'bootstrap aceptó un conflicto tardío con una ruta que no es enlace' >&2
  exit 1
fi
[ ! -e "$CONFLICT/mem/SKILL.md" ]
[ ! -e "$CONFLICT/mem/templates" ]

if "$ROOT/scripts/bootstrap.sh" --integrate >/dev/null 2>&1; then
  printf '%s\n' 'bootstrap aceptó un argumento retirado' >&2
  exit 1
fi

printf 'pruebas de bootstrap superadas\n'
