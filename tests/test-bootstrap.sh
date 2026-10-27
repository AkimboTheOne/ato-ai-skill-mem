#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
SKILL_VERSION=$(tr -d '\r\n' < "$ROOT/VERSION")
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT
PROJECT=$TEMP_ROOT/consumer
mkdir -p "$PROJECT"
CONTRACT=$ROOT/tests/fixtures/bootstrap-contract.tsv

contract_assertions() {
  awk -F '\t' -v scenario="$1" '$1 == scenario { print $3; exit }' "$CONTRACT"
}

contract_exit() {
  awk -F '\t' -v scenario="$1" '$1 == scenario { print $2; exit }' "$CONTRACT"
}

run_contract() {
  scenario=$1
  shift
  set +e
  output=$("$@" 2>&1)
  status=$?
  set -e
  expected=$(contract_exit "$scenario")
  [ "$status" = "$expected" ] || {
    printf 'exit code incumplido (%s): esperado %s, obtenido %s\n' "$scenario" "$expected" "$status" >&2
    return 1
  }
  printf '%s\n' "$output"
}

assert_contract_output() {
  scenario=$1
  output=$2
  assertions=$(contract_assertions "$scenario")
  old_ifs=$IFS
  IFS=';'
  for assertion in $assertions; do
    key=${assertion%%=*}
    expected=${assertion#*=}
    matched=false
    alternatives_ifs=$IFS
    IFS='|'
    for alternative in $expected; do
      if [ "$key" = error ]; then
        pattern="error: ${alternative}"
      else
        pattern="${key}: ${alternative}"
      fi
      if printf '%s\n' "$output" | grep -F "$pattern" >/dev/null; then matched=true; break; fi
    done
    IFS=$alternatives_ifs
    [ "$matched" = true ] || {
      printf 'contrato incumplido (%s): %s\n' "$scenario" "$assertion" >&2
      IFS=$old_ifs
      return 1
    }
  done
  IFS=$old_ifs
}

CONTEXT_NEW_PROJECT=$TEMP_ROOT/context-new
mkdir -p "$CONTEXT_NEW_PROJECT"
context_new_output=$(run_contract context-new "$ROOT/scripts/bootstrap.sh" --target "$CONTEXT_NEW_PROJECT" --contextualize)
printf '%s\n' "$context_new_output" | grep -F 'vault.initialization.state: new' >/dev/null
assert_contract_output context-new "$context_new_output"
printf '%s\n' "$context_new_output" | grep -F 'vault.context.wizard.phase.4: validate-and-authorize' >/dev/null
[ ! -e "$CONTEXT_NEW_PROJECT/mem" ]

source_status_output=$(run_contract source-status "$ROOT/scripts/bootstrap.sh" --source-status)
assert_contract_output source-status "$source_status_output"
source_target_rejected_output=$(run_contract source-target-rejected "$ROOT/scripts/bootstrap.sh" --source-status --target "$ROOT")
assert_contract_output source-target-rejected "$source_target_rejected_output"

STATE_PROJECT=$TEMP_ROOT/state-consumer
mkdir -p "$STATE_PROJECT"
state_output=$($ROOT/scripts/bootstrap.sh --target "$STATE_PROJECT" --init)
printf '%s\n' "$state_output" | grep -F 'vault.initialization.state: new' >/dev/null
STATE_VAULT=$STATE_PROJECT/mem/vault
STATE_MARKER=$STATE_VAULT/.ato-ai-skill-mem-version.yml
STATE_MARKER_HASH=$(cksum "$STATE_MARKER")
if $ROOT/scripts/bootstrap.sh --target "$STATE_PROJECT" --init >/dev/null 2>&1; then exit 1; fi
[ "$(cksum "$STATE_MARKER")" = "$STATE_MARKER_HASH" ]
sh "$ROOT/scripts/vault.sh" create-domain --vault "$STATE_VAULT" --id context --title Context
state_context_output=$(run_contract context-existing-ready "$ROOT/scripts/bootstrap.sh" --target "$STATE_PROJECT" --contextualize)
printf '%s\n' "$state_context_output" | grep -F 'vault.initialization.state: existing' >/dev/null
assert_contract_output context-existing-ready "$state_context_output"
printf '%s\n' "$state_context_output" | grep -F 'vault.context.domains.total: 1' >/dev/null
printf '%s\n' "$state_context_output" | grep -F 'vault.context.next_step: validate-and-authorize' >/dev/null
status_marker_hash=$(cksum "$STATE_MARKER")
status_output=$($ROOT/scripts/bootstrap.sh --target "$STATE_PROJECT" --status)
printf '%s\n' "$status_output" | grep -F 'vault.initialization.state: existing' >/dev/null
[ "$(cksum "$STATE_MARKER")" = "$status_marker_hash" ]

"$ROOT/scripts/bootstrap.sh" --target "$PROJECT" --integrate-codex
VAULT=$PROJECT/mem/vault
[ -L "$PROJECT/mem/VAULT_FORMAT" ]
[ -f "$VAULT/AGENTS.md" ]
[ -d "$VAULT/00_inbox/decisions-pending" ]
[ -d "$VAULT/20_domains" ]
[ -d "$VAULT/_templates" ]
[ "$(sed -n 's/^vault_format: *//p' "$VAULT/.ato-ai-skill-mem-version.yml")" = 3 ]
grep -F 'mem/vault/' "$PROJECT/.agents/skills/ato-ai-project-mem/SKILL.md" >/dev/null
grep -F 'mem/SKILL.md' "$PROJECT/.agents/skills/ato-ai-project-mem/SKILL.md" >/dev/null
! grep -F -- '--target .' "$PROJECT/.agents/skills/ato-ai-project-mem/SKILL.md" >/dev/null
sh "$ROOT/scripts/vault.sh" check --vault "$VAULT"

if "$ROOT/scripts/bootstrap.sh" --target "$ROOT" --status >/dev/null 2>&1; then exit 1; fi
integration_config_hash=$(cksum "$PROJECT/.ato-ai-skill-mem.yml")
integration_adapter_hash=$(cksum "$PROJECT/.agents/skills/ato-ai-project-mem/SKILL.md")
"$ROOT/scripts/bootstrap.sh" --target "$PROJECT" --integrate-codex
[ "$(cksum "$PROJECT/.ato-ai-skill-mem.yml")" = "$integration_config_hash" ]
[ "$(cksum "$PROJECT/.agents/skills/ato-ai-project-mem/SKILL.md")" = "$integration_adapter_hash" ]

CONFLICT_PROJECT=$TEMP_ROOT/conflict-codex
mkdir -p "$CONFLICT_PROJECT/.agents/skills/ato-ai-project-mem"
printf '%s\n' '# conflicting adapter' > "$CONFLICT_PROJECT/.agents/skills/ato-ai-project-mem/SKILL.md"
if "$ROOT/scripts/bootstrap.sh" --target "$CONFLICT_PROJECT" --integrate-codex >/dev/null 2>&1; then exit 1; fi
grep -F '# conflicting adapter' "$CONFLICT_PROJECT/.agents/skills/ato-ai-project-mem/SKILL.md" >/dev/null

CONFIG_CONFLICT_PROJECT=$TEMP_ROOT/config-conflict-codex
mkdir -p "$CONFIG_CONFLICT_PROJECT"
printf '%s\n' 'format: 3' 'vault:' '  path: elsewhere' > "$CONFIG_CONFLICT_PROJECT/.ato-ai-skill-mem.yml"
if "$ROOT/scripts/bootstrap.sh" --target "$CONFIG_CONFLICT_PROJECT" --integrate-codex >/dev/null 2>&1; then exit 1; fi
grep -F 'path: elsewhere' "$CONFIG_CONFLICT_PROJECT/.ato-ai-skill-mem.yml" >/dev/null

ROLE_PROJECT=$TEMP_ROOT/role-mismatch
mkdir -p "$ROLE_PROJECT/mem/vault"
printf '%s\n' 'format: 1' 'vault_kind: source' 'vault_format: 3' "skill_version: $SKILL_VERSION" 'source_revision: test' "source_tag: v$SKILL_VERSION" 'created_at: 2026-10-26' 'updated_at: 2026-10-26' > "$ROLE_PROJECT/mem/vault/.ato-ai-skill-mem-version.yml"
role_status=$($ROOT/scripts/bootstrap.sh --target "$ROLE_PROJECT" --status)
printf '%s\n' "$role_status" | grep -F 'vault.state: role-mismatch' >/dev/null
printf '%s\n' "$role_status" | grep -F 'vault.context.state: blocked' >/dev/null

if "$ROOT/scripts/bootstrap.sh" --target "$STATE_PROJECT" --update-vault >/dev/null 2>&1; then exit 1; fi
if "$ROOT/scripts/bootstrap.sh" --update-source-vault >/dev/null 2>&1; then exit 1; fi

LEGACY_PROJECT=$TEMP_ROOT/legacy-consumer
mkdir -p "$LEGACY_PROJECT/mem/workspace/records"
printf '%s\n' 'workspace_format: 1' 'created_at: 2026-10-26' > "$LEGACY_PROJECT/mem/workspace/.ato-ai-skill-mem-version.yml"
printf '%s\n' '# Legacy record' > "$LEGACY_PROJECT/mem/workspace/records/legacy.md"
"$ROOT/scripts/bootstrap.sh" --target "$LEGACY_PROJECT" --migrate-workspace-to-vault
[ ! -d "$LEGACY_PROJECT/mem/workspace" ]
[ -d "$LEGACY_PROJECT/mem/vault/records" ]
[ "$(sed -n 's/^vault_format: *//p' "$LEGACY_PROJECT/mem/vault/.ato-ai-skill-mem-version.yml")" = 3 ]

RELEASE_SOURCE=$TEMP_ROOT/release-source
mkdir -p "$RELEASE_SOURCE"
cp "$ROOT/SKILL.md" "$ROOT/VERSION" "$ROOT/VAULT_FORMAT" "$RELEASE_SOURCE/"
cp -R "$ROOT/references" "$ROOT/templates" "$ROOT/scripts" "$ROOT/vault" "$RELEASE_SOURCE/"
git -C "$RELEASE_SOURCE" init -q
git -C "$RELEASE_SOURCE" checkout -q -b master
git -C "$RELEASE_SOURCE" config user.email test@example.com
git -C "$RELEASE_SOURCE" config user.name 'Contract Tests'
git -C "$RELEASE_SOURCE" add .
git -C "$RELEASE_SOURCE" commit -qm 'test release fixture'
git -C "$RELEASE_SOURCE" tag "v$SKILL_VERSION"

UPDATE_PROJECT=$TEMP_ROOT/update-consumer
mkdir -p "$UPDATE_PROJECT"
"$RELEASE_SOURCE/scripts/bootstrap.sh" --target "$UPDATE_PROJECT" --init >/dev/null
UPDATE_MARKER=$UPDATE_PROJECT/mem/vault/.ato-ai-skill-mem-version.yml
awk '{ if ($0 ~ /^skill_version:/) print "skill_version: 0.4.0"; else print }' "$UPDATE_MARKER" > "$UPDATE_MARKER.tmp"
mv "$UPDATE_MARKER.tmp" "$UPDATE_MARKER"
"$RELEASE_SOURCE/scripts/bootstrap.sh" --target "$UPDATE_PROJECT" --update-vault >/dev/null
[ "$(sed -n 's/^skill_version: *//p' "$UPDATE_MARKER")" = "$SKILL_VERSION" ]

"$RELEASE_SOURCE/scripts/bootstrap.sh" --update-source-vault
[ "$(sed -n 's/^skill_version: *//p' "$RELEASE_SOURCE/vault/.ato-ai-skill-mem-version.yml")" = "$SKILL_VERSION" ]
[ "$(sed -n 's/^source_tag: *//p' "$RELEASE_SOURCE/vault/.ato-ai-skill-mem-version.yml")" = "v$SKILL_VERSION" ]

SOURCE_MIGRATION=$TEMP_ROOT/source-migration
mkdir -p "$SOURCE_MIGRATION/workspace/records"
cp "$ROOT/SKILL.md" "$ROOT/VERSION" "$ROOT/VAULT_FORMAT" "$SOURCE_MIGRATION/"
cp -R "$ROOT/references" "$ROOT/templates" "$ROOT/scripts" "$SOURCE_MIGRATION/"
printf '%s\n' 'workspace_format: 1' 'created_at: 2026-10-26' > "$SOURCE_MIGRATION/workspace/.ato-ai-skill-mem-version.yml"
printf '%s\n' '# Source legacy record' > "$SOURCE_MIGRATION/workspace/records/legacy.md"
"$SOURCE_MIGRATION/scripts/bootstrap.sh" --migrate-source-workspace-to-vault
[ ! -d "$SOURCE_MIGRATION/workspace" ]
[ -d "$SOURCE_MIGRATION/vault/records" ]
[ "$(sed -n 's/^vault_kind: *//p' "$SOURCE_MIGRATION/vault/.ato-ai-skill-mem-version.yml")" = source ]

for option in --vault --id --title --record; do
  error_file="$TEMP_ROOT/${option#--}.err"
  if sh "$ROOT/scripts/vault.sh" check "$option" 2>"$error_file"; then exit 1; fi
  grep -F "error: $option requiere un valor" "$error_file" >/dev/null
done
sh "$ROOT/scripts/vault.sh" create-domain --vault "$VAULT" --id alpha --title Alpha
[ -f "$VAULT/20_domains/alpha/AGENTS.md" ]
[ -f "$VAULT/20_domains/alpha/domain.yml" ]
sh "$ROOT/scripts/vault.sh" check --vault "$VAULT"
[ -d "$VAULT/99_runtime/rag/indexes" ]
[ -f "$VAULT/.gitignore" ]
grep -F '99_runtime/rag/indexes/*/data/' "$VAULT/.gitignore" >/dev/null
rm -rf "$VAULT/99_runtime"
sh "$ROOT/scripts/vault.sh" check --vault "$VAULT"
ln -s "$TEMP_ROOT" "$VAULT/99_runtime"
if sh "$ROOT/scripts/vault.sh" check --vault "$VAULT" >/dev/null 2>&1; then exit 1; fi
rm "$VAULT/99_runtime"
mkdir -p "$VAULT/99_runtime"
ln -s "$TEMP_ROOT" "$VAULT/99_runtime/rag"
if sh "$ROOT/scripts/vault.sh" check --vault "$VAULT" >/dev/null 2>&1; then exit 1; fi
rm "$VAULT/99_runtime/rag"
mkdir -p "$VAULT/99_runtime/rag/indexes/sample/data"
printf '%s\n' '# Manifiesto futuro reservado' > "$VAULT/99_runtime/rag/manifest.yml"
sh "$ROOT/scripts/vault.sh" check --vault "$VAULT"
rm -rf "$VAULT/99_runtime"
sh "$ROOT/scripts/vault.sh" init-layout --vault "$VAULT"
cp "$VAULT/20_domains/alpha/domain.yml" "$VAULT/20_domains/alpha/domain.yml.saved"
grep -v '^scope:' "$VAULT/20_domains/alpha/domain.yml.saved" > "$VAULT/20_domains/alpha/domain.yml"
if sh "$ROOT/scripts/vault.sh" check --vault "$VAULT" >/dev/null 2>&1; then exit 1; fi
mv "$VAULT/20_domains/alpha/domain.yml.saved" "$VAULT/20_domains/alpha/domain.yml"
printf '%s\n' '# Índice raíz inválido' > "$VAULT/INDEX.md"
if sh "$ROOT/scripts/vault.sh" check --vault "$VAULT" >/dev/null 2>&1; then exit 1; fi
rm "$VAULT/INDEX.md"
sh "$ROOT/scripts/vault.sh" create-domain --vault "$VAULT" --id api-gateway --title 'Arquitectura: "R&D/Platform"'
[ "$(sed -n 's/^title: *//p' "$VAULT/20_domains/api-gateway/domain.yml")" = '"Arquitectura: \"R&D/Platform\""' ]
if sh "$ROOT/scripts/vault.sh" create-domain --vault "$VAULT" --id Alpha >/dev/null 2>&1; then exit 1; fi
if sh "$ROOT/scripts/vault.sh" create-domain --vault "$VAULT" --id multilinea --title 'primera
segunda' >/dev/null 2>&1; then exit 1; fi
[ ! -e "$VAULT/20_domains/multilinea" ]
if sh "$ROOT/scripts/vault.sh" create-domain --vault "$VAULT" --id empty-title --title '' >/dev/null 2>&1; then exit 1; fi
if sh "$ROOT/scripts/vault.sh" create-domain --vault "$VAULT" --id blank-title --title '   ' >/dev/null 2>&1; then exit 1; fi
[ ! -e "$VAULT/20_domains/empty-title" ] && [ ! -e "$VAULT/20_domains/blank-title" ]
touch "$VAULT/20_domains/.unexpected"
if sh "$ROOT/scripts/vault.sh" check --vault "$VAULT" >/dev/null 2>&1; then exit 1; fi
rm "$VAULT/20_domains/.unexpected"
printf '%s\n' 'unexpected file' > "$VAULT/20_domains/unexpected.md"
if sh "$ROOT/scripts/vault.sh" check --vault "$VAULT" >/dev/null 2>&1; then exit 1; fi
rm "$VAULT/20_domains/unexpected.md"
mkdir "$VAULT/20_domains/.temporary"
if sh "$ROOT/scripts/vault.sh" check --vault "$VAULT" >/dev/null 2>&1; then exit 1; fi
rmdir "$VAULT/20_domains/.temporary"
ln -s "$VAULT/20_domains/alpha" "$VAULT/20_domains/linked-domain"
if sh "$ROOT/scripts/vault.sh" check --vault "$VAULT" >/dev/null 2>&1; then exit 1; fi
rm "$VAULT/20_domains/linked-domain"
mkdir -p "$VAULT/records"
printf '%s\n' '# Legacy record' > "$VAULT/records/2026-10-25--legacy.md"
sh "$ROOT/scripts/vault.sh" migration-plan --vault "$VAULT"
[ -f "$VAULT/00_inbox/decisions-pending/2026-10-25--legacy.md" ]
sh "$ROOT/scripts/vault.sh" migration-apply --vault "$VAULT" --domain alpha --record 2026-10-25--legacy.md
[ -f "$VAULT/20_domains/alpha/records/2026-10-25--legacy.md" ]
grep -F 'migration-apply' "$VAULT/_indexes/action-log.md" >/dev/null
grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \| migration-apply' "$VAULT/_indexes/action-log.md" >/dev/null
printf '%s\n' '# Protected root file' > "$VAULT/guard.md"
if sh "$ROOT/scripts/vault.sh" migration-apply --vault "$VAULT" --domain alpha --record ../guard.md >/dev/null 2>&1; then exit 1; fi
[ -f "$VAULT/guard.md" ]
[ ! -e "$VAULT/20_domains/alpha/guard.md" ]
printf '%s\n' '# Symlink source' > "$TEMP_ROOT/outside-record.md"
ln -s "$TEMP_ROOT/outside-record.md" "$VAULT/records/linked.md"
if sh "$ROOT/scripts/vault.sh" migration-apply --vault "$VAULT" --domain alpha --record linked.md >/dev/null 2>&1; then exit 1; fi
[ -L "$VAULT/records/linked.md" ] && [ ! -e "$VAULT/20_domains/alpha/records/linked.md" ]
rm "$VAULT/records/linked.md"
printf '%s\n' '# Rollback record' > "$VAULT/records/2026-10-25--rollback.md"
mv "$VAULT/_indexes/action-log.md" "$VAULT/_indexes/action-log.md.saved"
mkdir "$VAULT/_indexes/action-log.md"
if sh "$ROOT/scripts/vault.sh" migration-apply --vault "$VAULT" --domain alpha --record 2026-10-25--rollback.md >/dev/null 2>&1; then exit 1; fi
[ -f "$VAULT/records/2026-10-25--rollback.md" ]
[ ! -e "$VAULT/20_domains/alpha/records/2026-10-25--rollback.md" ]
rm -rf "$VAULT/_indexes/action-log.md"
mv "$VAULT/_indexes/action-log.md.saved" "$VAULT/_indexes/action-log.md"
printf '%s\n' '# Log symlink record' > "$VAULT/records/2026-10-25--log-link.md"
mv "$VAULT/_indexes/action-log.md" "$VAULT/_indexes/action-log.md.saved"
ln -s "$VAULT/_indexes/action-log.md.saved" "$VAULT/_indexes/action-log.md"
if sh "$ROOT/scripts/vault.sh" migration-apply --vault "$VAULT" --domain alpha --record 2026-10-25--log-link.md >/dev/null 2>&1; then exit 1; fi
[ -f "$VAULT/records/2026-10-25--log-link.md" ] && [ ! -e "$VAULT/20_domains/alpha/records/2026-10-25--log-link.md" ]
rm "$VAULT/_indexes/action-log.md"
mv "$VAULT/_indexes/action-log.md.saved" "$VAULT/_indexes/action-log.md"
mv "$VAULT/_maps/INDEX.md" "$VAULT/_maps/INDEX.md.saved"
ln -s "$VAULT/_maps/INDEX.md.saved" "$VAULT/_maps/INDEX.md"
if sh "$ROOT/scripts/vault.sh" check --vault "$VAULT" >/dev/null 2>&1; then exit 1; fi
rm "$VAULT/_maps/INDEX.md"
mv "$VAULT/_maps/INDEX.md.saved" "$VAULT/_maps/INDEX.md"
mv "$VAULT/_indexes/action-log.md" "$VAULT/_indexes/action-log.md.saved"
mkdir "$VAULT/_indexes/action-log.md"
if sh "$ROOT/scripts/vault.sh" check --vault "$VAULT" >/dev/null 2>&1; then exit 1; fi
rm -rf "$VAULT/_indexes/action-log.md"
mv "$VAULT/_indexes/action-log.md.saved" "$VAULT/_indexes/action-log.md"

MIGRATION_PROJECT=$TEMP_ROOT/migration-consumer
mkdir -p "$MIGRATION_PROJECT/mem/vault/records"
MIGRATION_VAULT=$MIGRATION_PROJECT/mem/vault
printf '%s\n' 'format: 1' 'vault_kind: consumer' 'vault_format: 2' 'skill_version: 0.2.0' 'source_revision: old' 'source_tag: v0.2.0' 'created_at: 2026-01-01' 'updated_at: 2026-01-01' > "$MIGRATION_VAULT/.ato-ai-skill-mem-version.yml"
printf '%s\n' '# Índice legado' > "$MIGRATION_VAULT/INDEX.md"
cp "$MIGRATION_VAULT/INDEX.md" "$TEMP_ROOT/legacy-index.expected"
printf '%s\n' '# Registro legado' > "$MIGRATION_VAULT/records/2026-01-01--legacy&record.md"
migration_context_output=$(run_contract context-blocked "$ROOT/scripts/bootstrap.sh" --target "$MIGRATION_PROJECT" --contextualize)
assert_contract_output context-blocked "$migration_context_output"
"$ROOT/scripts/bootstrap.sh" --target "$MIGRATION_PROJECT" --migrate-vault-format
[ "$(sed -n 's/^vault_format: *//p' "$MIGRATION_VAULT/.ato-ai-skill-mem-version.yml")" = 2 ]
[ -f "$MIGRATION_VAULT/00_inbox/decisions-pending/2026-01-01--legacy&record.md" ]
if "$ROOT/scripts/bootstrap.sh" --target "$MIGRATION_PROJECT" --migrate-vault-format --finalize >/dev/null 2>&1; then exit 1; fi
[ -f "$MIGRATION_VAULT/INDEX.md" ]
sh "$ROOT/scripts/vault.sh" create-domain --vault "$MIGRATION_VAULT" --id migrated --title Migrated
sh "$ROOT/scripts/vault.sh" migration-apply --vault "$MIGRATION_VAULT" --domain migrated --record '2026-01-01--legacy&record.md'
printf '%s\n' 'contenido no Markdown' > "$MIGRATION_VAULT/records/legacy.txt"
if "$ROOT/scripts/bootstrap.sh" --target "$MIGRATION_PROJECT" --migrate-vault-format --finalize >/dev/null 2>&1; then exit 1; fi
[ "$(sed -n 's/^vault_format: *//p' "$MIGRATION_VAULT/.ato-ai-skill-mem-version.yml")" = 2 ]
[ -f "$MIGRATION_VAULT/INDEX.md" ]
rm "$MIGRATION_VAULT/records/legacy.txt"
"$ROOT/scripts/bootstrap.sh" --target "$MIGRATION_PROJECT" --migrate-vault-format --finalize
[ "$(sed -n 's/^vault_format: *//p' "$MIGRATION_VAULT/.ato-ai-skill-mem-version.yml")" = 3 ]
[ ! -e "$MIGRATION_VAULT/INDEX.md" ]
cmp "$TEMP_ROOT/legacy-index.expected" "$MIGRATION_VAULT/40_archive/legacy-root-INDEX.md"
sh "$ROOT/scripts/vault.sh" check --vault "$MIGRATION_VAULT"

CONFLICT_PROJECT=$TEMP_ROOT/conflict-consumer
mkdir -p "$CONFLICT_PROJECT/mem/vault/40_archive"
CONFLICT_VAULT=$CONFLICT_PROJECT/mem/vault
printf '%s\n' 'format: 1' 'vault_kind: consumer' 'vault_format: 2' 'skill_version: 0.2.0' 'source_revision: old' 'source_tag: v0.2.0' 'created_at: 2026-01-01' 'updated_at: 2026-01-01' > "$CONFLICT_VAULT/.ato-ai-skill-mem-version.yml"
printf '%s\n' '# Índice legado' > "$CONFLICT_VAULT/INDEX.md"
printf '%s\n' '# Archivo existente' > "$CONFLICT_VAULT/40_archive/legacy-root-INDEX.md"
"$ROOT/scripts/bootstrap.sh" --target "$CONFLICT_PROJECT" --migrate-vault-format
if "$ROOT/scripts/bootstrap.sh" --target "$CONFLICT_PROJECT" --migrate-vault-format --finalize >/dev/null 2>&1; then exit 1; fi
[ "$(sed -n 's/^vault_format: *//p' "$CONFLICT_VAULT/.ato-ai-skill-mem-version.yml")" = 2 ]
[ -f "$CONFLICT_VAULT/INDEX.md" ]

AMBIGUOUS_PROJECT=$TEMP_ROOT/ambiguous-consumer
mkdir -p "$AMBIGUOUS_PROJECT/mem/vault"
AMBIGUOUS_VAULT=$AMBIGUOUS_PROJECT/mem/vault
printf '%s\n' 'format: 1' 'vault_kind: consumer' 'vault_format: 2' 'vault_format: 2' 'skill_version: 0.2.0' 'created_at: 2026-01-01' > "$AMBIGUOUS_VAULT/.ato-ai-skill-mem-version.yml"
if "$ROOT/scripts/bootstrap.sh" --target "$AMBIGUOUS_PROJECT" --migrate-vault-format >/dev/null 2>&1; then exit 1; fi
[ ! -e "$AMBIGUOUS_VAULT/AGENTS.md" ]

INCOMPLETE_PROJECT=$TEMP_ROOT/incomplete-consumer
mkdir -p "$INCOMPLETE_PROJECT/mem/vault"
INCOMPLETE_VAULT=$INCOMPLETE_PROJECT/mem/vault
printf '%s\n' 'format: 1' 'vault_kind: consumer' 'vault_format: 2' 'skill_version: 0.2.0' 'created_at: 2026-01-01' > "$INCOMPLETE_VAULT/.ato-ai-skill-mem-version.yml"
if "$ROOT/scripts/bootstrap.sh" --target "$INCOMPLETE_PROJECT" --migrate-vault-format --finalize >/dev/null 2>&1; then exit 1; fi
[ ! -e "$INCOMPLETE_VAULT/AGENTS.md" ]

PLAN_VAULT=$TEMP_ROOT/plan-vault
mkdir -p "$PLAN_VAULT/records" "$PLAN_VAULT/00_inbox/decisions-pending/z-conflict.md"
printf '%s\n' '# Nuevo' > "$PLAN_VAULT/records/a-new.md"
printf '%s\n' '# Conflicto' > "$PLAN_VAULT/records/z-conflict.md"
if sh "$ROOT/scripts/vault.sh" migration-plan --vault "$PLAN_VAULT" >/dev/null 2>&1; then exit 1; fi
[ ! -e "$PLAN_VAULT/00_inbox/decisions-pending/a-new.md" ]
PLAN_LINK_VAULT=$TEMP_ROOT/plan-link-vault
mkdir -p "$PLAN_LINK_VAULT/records"
printf '%s\n' '# Regular' > "$PLAN_LINK_VAULT/records/a-regular.md"
ln -s "$TEMP_ROOT/outside-record.md" "$PLAN_LINK_VAULT/records/z-linked.md"
if sh "$ROOT/scripts/vault.sh" migration-plan --vault "$PLAN_LINK_VAULT" >/dev/null 2>&1; then exit 1; fi
[ ! -e "$PLAN_LINK_VAULT/00_inbox/decisions-pending/a-regular.md" ]
printf 'pruebas de bootstrap y vault superadas\n'
