#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT

[ -f "$ROOT/.agents/skills/ato-ai-source-mem/SKILL.md" ]
[ ! -L "$ROOT/.agents/skills/ato-ai-source-mem/SKILL.md" ]
grep -F -x 'exclusivamente en `workspace/`.' "$ROOT/.agents/skills/ato-ai-source-mem/SKILL.md" >/dev/null
grep -F -x 'No uses `mem/workspace/`, no ejecutes `--target .` y no copies, reemplaces ni' "$ROOT/.agents/skills/ato-ai-source-mem/SKILL.md" >/dev/null

PROJECT=$TEMP_ROOT/consumer
LEGACY=$TEMP_ROOT/legacy
mkdir -p "$PROJECT"
printf '%s\n' 'before' > "$PROJECT/AGENTS.md"
cp "$PROJECT/AGENTS.md" "$PROJECT/AGENTS.before"

"$ROOT/scripts/bootstrap.sh" --target "$PROJECT"

[ -L "$PROJECT/mem/SKILL.md" ]
[ "$(readlink "$PROJECT/mem/SKILL.md")" = "$ROOT/SKILL.md" ]
[ -L "$PROJECT/mem/VERSION" ]
[ -L "$PROJECT/mem/WORKSPACE_FORMAT" ]
[ -L "$PROJECT/mem/references" ]
[ -L "$PROJECT/mem/templates" ]
[ -L "$PROJECT/mem/scripts" ]
[ -f "$PROJECT/mem/workspace/INDEX.md" ]
[ -f "$PROJECT/mem/workspace/.ato-ai-skill-mem-version.yml" ]
[ "$(sed -n 's/^workspace_kind: *//p' "$PROJECT/mem/workspace/.ato-ai-skill-mem-version.yml")" = 'consumer' ]
[ "$(sed -n 's/^workspace_format: *//p' "$PROJECT/mem/workspace/.ato-ai-skill-mem-version.yml")" = '1' ]
[ -d "$PROJECT/mem/workspace/records" ]
cmp -s "$PROJECT/AGENTS.md" "$PROJECT/AGENTS.before"
"$ROOT/scripts/bootstrap.sh" --target "$PROJECT" --status | grep -F -x 'integration.codex.state: not-configured' >/dev/null

"$ROOT/scripts/bootstrap.sh" --target "$PROJECT" --integrate-codex
cmp -s "$PROJECT/.ato-ai-skill-mem.yml" "$ROOT/templates/integrations/host-config.yml"
[ -f "$PROJECT/.agents/skills/ato-ai-project-mem/SKILL.md" ]
[ ! -L "$PROJECT/.agents/skills/ato-ai-project-mem/SKILL.md" ]
cmp -s "$PROJECT/.agents/skills/ato-ai-project-mem/SKILL.md" "$ROOT/templates/integrations/codex/SKILL.md"
"$ROOT/scripts/bootstrap.sh" --target "$PROJECT" --status | grep -F -x 'integration.codex.state: aligned' >/dev/null
"$ROOT/scripts/bootstrap.sh" --target "$PROJECT" --integrate-codex
cmp -s "$PROJECT/AGENTS.md" "$PROJECT/AGENTS.before"

INTEGRATION_CONFLICT=$TEMP_ROOT/integration-conflict
mkdir -p "$INTEGRATION_CONFLICT"
printf '%s\n' 'format: 9' > "$INTEGRATION_CONFLICT/.ato-ai-skill-mem.yml"
if "$ROOT/scripts/bootstrap.sh" --target "$INTEGRATION_CONFLICT" --integrate-codex >/dev/null 2>&1; then
  printf '%s\n' 'bootstrap aceptó una configuración de integración incompatible' >&2
  exit 1
fi
[ ! -e "$INTEGRATION_CONFLICT/mem/SKILL.md" ]
[ ! -e "$INTEGRATION_CONFLICT/.agents" ]

"$ROOT/scripts/bootstrap.sh" --source-status | grep -F -x 'workspace.kind: source' >/dev/null
"$ROOT/scripts/bootstrap.sh" --source-status | grep -F -x 'workspace.expected_kind: source' >/dev/null
if "$ROOT/scripts/bootstrap.sh" --target "$ROOT" --status >/dev/null 2>&1; then
  printf '%s\n' 'bootstrap aceptó la raíz fuente como consumidor' >&2
  exit 1
fi
if "$ROOT/scripts/bootstrap.sh" --update-source-workspace >/dev/null 2>&1; then
  printf '%s\n' 'la actualización de fuente aceptó un checkout no apto' >&2
  exit 1
fi

SOURCE_FIXTURE=$TEMP_ROOT/source-release
cp -R "$ROOT" "$SOURCE_FIXTURE"
git -C "$SOURCE_FIXTURE" config user.email test@example.invalid
git -C "$SOURCE_FIXTURE" config user.name test
git -C "$SOURCE_FIXTURE" add .
git -C "$SOURCE_FIXTURE" commit -qm 'fixture release'
git -C "$SOURCE_FIXTURE" branch -f master HEAD
git -C "$SOURCE_FIXTURE" switch -q master
git -C "$SOURCE_FIXTURE" tag -f v0.1.0 HEAD
"$SOURCE_FIXTURE/scripts/bootstrap.sh" --update-source-workspace
"$SOURCE_FIXTURE/scripts/bootstrap.sh" --source-status | grep -F -x 'workspace.source_tag: v0.1.0' >/dev/null
"$SOURCE_FIXTURE/scripts/bootstrap.sh" --source-status | grep -F -x "workspace.source_revision: $(git -C "$SOURCE_FIXTURE" rev-parse HEAD)" >/dev/null

mkdir -p "$LEGACY/mem/workspace/records"
printf '%s\n' '# Legacy memory' > "$LEGACY/mem/workspace/INDEX.md"
"$ROOT/scripts/bootstrap.sh" --target "$LEGACY" --status | grep -F -x 'workspace.data_compatibility: compatible' >/dev/null
"$ROOT/scripts/bootstrap.sh" --target "$LEGACY" --status | grep -F -x 'workspace.state: legacy-compatible' >/dev/null

"$ROOT/scripts/bootstrap.sh" --target "$PROJECT" --status | grep -F -x 'workspace.state: aligned' >/dev/null
"$PROJECT/mem/scripts/bootstrap.sh" --target "$PROJECT" --status | grep -F -x 'workspace.state: aligned' >/dev/null
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
