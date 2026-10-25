#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT

PROJECT=$TEMP_ROOT/consumer
mkdir -p "$PROJECT"
printf '%s\n' before > "$PROJECT/AGENTS.md"
cp "$PROJECT/AGENTS.md" "$PROJECT/AGENTS.before"

"$ROOT/scripts/bootstrap.sh" --target "$PROJECT"
[ -f "$PROJECT/mem/vault/INDEX.md" ]
[ -f "$PROJECT/mem/vault/.ato-ai-skill-mem-version.yml" ]
[ "$(sed -n 's/^vault_kind: *//p' "$PROJECT/mem/vault/.ato-ai-skill-mem-version.yml")" = consumer ]
[ "$(sed -n 's/^vault_format: *//p' "$PROJECT/mem/vault/.ato-ai-skill-mem-version.yml")" = 2 ]
[ -d "$PROJECT/mem/vault/records" ]
cmp -s "$PROJECT/AGENTS.md" "$PROJECT/AGENTS.before"
"$ROOT/scripts/bootstrap.sh" --target "$PROJECT" --status | grep -F -x 'vault.state: aligned' >/dev/null

"$ROOT/scripts/bootstrap.sh" --target "$PROJECT" --integrate-codex
cmp -s "$PROJECT/.ato-ai-skill-mem.yml" "$ROOT/templates/integrations/host-config.yml"
grep -F -x '  path: mem/vault' "$PROJECT/.ato-ai-skill-mem.yml" >/dev/null
grep -F 'mem/vault' "$PROJECT/.agents/skills/ato-ai-project-mem/SKILL.md" >/dev/null

LEGACY=$TEMP_ROOT/legacy
mkdir -p "$LEGACY/mem/workspace/records"
printf '%s\n' '# Legacy memory' > "$LEGACY/mem/workspace/INDEX.md"
printf '%s\n' record > "$LEGACY/mem/workspace/records/one.md"
cat > "$LEGACY/mem/workspace/.ato-ai-skill-mem-version.yml" <<'EOF'
format: 1
workspace_kind: consumer
workspace_format: 1
skill_version: 0.1.0
created_at: 2025-01-01
EOF
"$ROOT/scripts/bootstrap.sh" --target "$LEGACY" --status | grep -F -x 'vault.data_compatibility: migration-required' >/dev/null
if "$ROOT/scripts/bootstrap.sh" --target "$LEGACY" >/dev/null 2>&1; then exit 1; fi
"$ROOT/scripts/bootstrap.sh" --target "$LEGACY" --migrate-workspace-to-vault
[ ! -e "$LEGACY/mem/workspace" ]
[ -f "$LEGACY/mem/vault/records/one.md" ]
[ "$(cat "$LEGACY/mem/vault/INDEX.md")" = '# Legacy memory' ]
[ "$(sed -n 's/^vault_format: *//p' "$LEGACY/mem/vault/.ato-ai-skill-mem-version.yml")" = 2 ]

CONFLICT=$TEMP_ROOT/conflict
mkdir -p "$CONFLICT/mem/workspace" "$CONFLICT/mem/vault"
printf '%s\n' old > "$CONFLICT/mem/workspace/INDEX.md"
if "$ROOT/scripts/bootstrap.sh" --target "$CONFLICT" --migrate-workspace-to-vault >/dev/null 2>&1; then exit 1; fi
[ -d "$CONFLICT/mem/workspace" ]

if "$ROOT/scripts/bootstrap.sh" --target "$ROOT" --status >/dev/null 2>&1; then exit 1; fi
"$ROOT/scripts/bootstrap.sh" --source-status | grep -F -x 'vault.kind: source' >/dev/null

printf 'pruebas de bootstrap superadas\n'
