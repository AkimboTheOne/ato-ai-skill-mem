#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT

PROJECT=$TEMP_ROOT/consumer
mkdir -p "$PROJECT"
printf '%s\n' 'before' > "$PROJECT/AGENTS.md"
cp "$PROJECT/AGENTS.md" "$PROJECT/AGENTS.before"

"$ROOT/scripts/bootstrap.sh" --target "$PROJECT"

[ -L "$PROJECT/mem/SKILL.md" ]
[ "$(readlink "$PROJECT/mem/SKILL.md")" = "$ROOT/SKILL.md" ]
[ -L "$PROJECT/mem/references" ]
[ -L "$PROJECT/mem/templates" ]
[ -f "$PROJECT/mem/workspace/INDEX.md" ]
[ -d "$PROJECT/mem/workspace/records" ]
cmp -s "$PROJECT/AGENTS.md" "$PROJECT/AGENTS.before"

printf '%s\n' '# Local memory' > "$PROJECT/mem/workspace/INDEX.md"
"$ROOT/scripts/bootstrap.sh" --target "$PROJECT"
grep -F -x '# Local memory' "$PROJECT/mem/workspace/INDEX.md" >/dev/null
cmp -s "$PROJECT/AGENTS.md" "$PROJECT/AGENTS.before"

CONFLICT=$TEMP_ROOT/conflict
mkdir -p "$CONFLICT/mem/references"
if "$ROOT/scripts/bootstrap.sh" --target "$CONFLICT" >/dev/null 2>&1; then
  printf '%s\n' 'bootstrap accepted a late non-link conflict' >&2
  exit 1
fi
[ ! -e "$CONFLICT/mem/SKILL.md" ]
[ ! -e "$CONFLICT/mem/templates" ]

if "$ROOT/scripts/bootstrap.sh" --integrate >/dev/null 2>&1; then
  printf '%s\n' 'bootstrap accepted a removed argument' >&2
  exit 1
fi

printf 'bootstrap tests passed\n'
