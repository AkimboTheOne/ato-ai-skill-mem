#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT
PROJECT=$TEMP_ROOT/consumer
mkdir -p "$PROJECT"
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
sh "$ROOT/scripts/vault.sh" create-domain --vault "$VAULT" --id alpha --title Alpha
[ -f "$VAULT/20_domains/alpha/AGENTS.md" ]
[ -f "$VAULT/20_domains/alpha/domain.yml" ]
sh "$ROOT/scripts/vault.sh" check --vault "$VAULT"
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
