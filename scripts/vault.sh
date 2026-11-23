#!/bin/sh

set -eu

COMMAND=${1:-}
[ -n "$COMMAND" ] || { printf '%s\n' 'uso: vault.sh <init-layout|create-domain|check|migration-plan|migration-apply> [...]' >&2; exit 1; }
shift

fail() { printf '%s\n' "error: $*" >&2; exit 1; }
require_value() {
  [ "$#" -ge 2 ] || fail "$1 requiere un valor"
  case "$2" in
    --*) fail "$1 requiere un valor" ;;
  esac
}

DOMAIN_ID=''
DOMAIN_TITLE=''
RECORD=''
TITLE_SET=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --id|--domain) require_value "$@"; DOMAIN_ID=$2; shift 2 ;;
    --title) require_value "$@"; DOMAIN_TITLE=$2; TITLE_SET=true; shift 2 ;;
    --record) require_value "$@"; RECORD=$2; shift 2 ;;
    *) printf '%s\n' "error: argumento desconocido: $1" >&2; exit 1 ;;
  esac
done
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
SKILL_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
VAULT=$SKILL_ROOT/vault
[ -d "$VAULT" ] || fail "la vault no existe: $VAULT"
[ ! -L "$VAULT" ] || fail 'la vault de la skill no puede ser un symlink'
LAYOUT=$SKILL_ROOT/templates/vault-layout

valid_new_id() {
  [ "${#1}" -le 63 ] && printf '%s\n' "$1" | grep -E '^[a-z0-9]+(-[a-z0-9]+)*$' >/dev/null || return 1
  case "$1" in con|prn|aux|nul|com[1-9]|lpt[1-9]) return 1 ;; esac
}
valid_id() { printf '%s\n' "$1" | grep -E '^[a-z0-9][a-z0-9-]{0,62}$' >/dev/null; }
local_file() { [ -f "$1" ] && [ ! -L "$1" ]; }
local_dir() { [ -d "$1" ] && [ ! -L "$1" ]; }
copy_if_missing() { [ -e "$2" ] || cp "$1" "$2"; }
yaml_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
single_line() { [ "$(printf '%s\n' "$1" | wc -l | tr -d '[:space:]')" = 1 ]; }
init_layout() {
  for dir in 00_inbox/decisions-pending 10_areas 20_domains 30_resources 40_archive 50_daily 60_exports _indexes _maps _templates; do mkdir -p "$VAULT/$dir"; done
  copy_if_missing "$LAYOUT/AGENTS.md" "$VAULT/AGENTS.md"
  for name in domain.yml domain-AGENTS.md domain-INDEX.md area.md daily.md pending-decision.md export.md resource.md map.md archive.md; do copy_if_missing "$LAYOUT/$name" "$VAULT/_templates/$name"; done
  [ -e "$VAULT/_indexes/INDEX.md" ] || printf '# Índices de la vault\n' > "$VAULT/_indexes/INDEX.md"
  [ -e "$VAULT/_indexes/action-log.md" ] || printf '# Registro de acciones\n\n' > "$VAULT/_indexes/action-log.md"
  [ -e "$VAULT/_maps/INDEX.md" ] || printf '# Mapas de la vault\n' > "$VAULT/_maps/INDEX.md"
}
create_domain() {
  valid_new_id "$DOMAIN_ID" || fail '--id inválido o reservado: usa minúsculas, dígitos y guiones simples'
  if [ "$TITLE_SET" = false ]; then DOMAIN_TITLE=$DOMAIN_ID; fi
  [ -n "$(printf '%s' "$DOMAIN_TITLE" | tr -d '[:space:]')" ] || fail '--title no puede estar vacío ni contener solo espacios'
  single_line "$DOMAIN_TITLE" || fail '--title debe ser una sola línea'
  init_layout
  DOMAIN=$VAULT/20_domains/$DOMAIN_ID
  [ ! -e "$DOMAIN" ] || fail "el dominio ya existe: $DOMAIN_ID"
  TMP_DOMAIN=$(mktemp -d "$VAULT/20_domains/.${DOMAIN_ID}.tmp.XXXXXX") || fail 'no se pudo preparar el dominio'
  ESCAPED_TITLE=$(yaml_escape "$DOMAIN_TITLE")
  if ! mkdir -p "$TMP_DOMAIN/records" "$TMP_DOMAIN/resources" \
    || ! { printf '%s\n' 'format: 1' "id: $DOMAIN_ID" "title: \"$ESCAPED_TITLE\"" 'status: active' 'scope: contextual' 'areas: []' 'routing:' '  rules: []'; } > "$TMP_DOMAIN/domain.yml" \
    || ! { sed '/^# Dominio: /,$d' "$LAYOUT/domain-AGENTS.md"; printf '# Dominio: %s\n' "$DOMAIN_TITLE"; sed -n '/^# Dominio: /,$p' "$LAYOUT/domain-AGENTS.md" | sed '1d'; } > "$TMP_DOMAIN/AGENTS.md" \
    || ! cp "$LAYOUT/domain-INDEX.md" "$TMP_DOMAIN/INDEX.md" \
    || ! mv "$TMP_DOMAIN" "$DOMAIN"; then
    rm -rf "$TMP_DOMAIN"
    fail "no se pudo crear el dominio: $DOMAIN_ID"
  fi
}
check_vault() {
  local_file "$SKILL_ROOT/VAULT_FORMAT" || fail 'falta VAULT_FORMAT local en la raíz de la skill'
  vault_format_value=$(tr -d '[:space:]' < "$SKILL_ROOT/VAULT_FORMAT")
  [ "$vault_format_value" = 3 ] || fail "formato de vault incompatible: $vault_format_value (compatible: 3)"
  local_file "$VAULT/AGENTS.md" || fail 'falta archivo local vault/AGENTS.md'
  [ ! -e "$VAULT/INDEX.md" ] || fail 'INDEX.md raíz heredado; archívalo antes de validar formato 3'
  for dir in 00_inbox 10_areas 20_domains 30_resources 40_archive 50_daily 60_exports _indexes _maps _templates; do local_dir "$VAULT/$dir" || fail "falta directorio local: $dir"; done
  for file in _indexes/INDEX.md _indexes/action-log.md _maps/INDEX.md; do local_file "$VAULT/$file" || fail "falta archivo canónico local: $file"; done
  for file in domain.yml domain-AGENTS.md domain-INDEX.md area.md daily.md pending-decision.md export.md resource.md map.md archive.md; do local_file "$VAULT/_templates/$file" || fail "falta plantilla canónica local: $file"; done
  ids=''
  for domain in "$VAULT"/20_domains/* "$VAULT"/20_domains/.[!.]* "$VAULT"/20_domains/..?*; do
    [ -e "$domain" ] || continue
    local_dir "$domain" || fail "dominio inválido: $domain"
    id=$(sed -n 's/^id: *//p' "$domain/domain.yml" 2>/dev/null | sed -n '1p')
    format=$(sed -n 's/^format: *//p' "$domain/domain.yml" 2>/dev/null | sed -n '1p')
    title=$(sed -n 's/^title: *//p' "$domain/domain.yml" 2>/dev/null | sed -n '1p')
    status=$(sed -n 's/^status: *//p' "$domain/domain.yml" 2>/dev/null | sed -n '1p')
    scope=$(sed -n 's/^scope: *//p' "$domain/domain.yml" 2>/dev/null | sed -n '1p')
    local_file "$domain/AGENTS.md" && local_file "$domain/INDEX.md" && local_dir "$domain/records" && local_dir "$domain/resources" || fail "paquete incompleto: $(basename "$domain")"
    valid_id "$id" && [ "$(basename "$domain")" = "$id" ] || fail "id inválido: $domain"
    [ "$format" = 1 ] && [ -n "$(printf '%s' "$title" | tr -d '[:space:]')" ] && [ -n "$scope" ] && { grep -F -x 'areas: []' "$domain/domain.yml" >/dev/null || { grep -F -x 'areas:' "$domain/domain.yml" >/dev/null && grep -E '^  - ' "$domain/domain.yml" >/dev/null; }; } && { [ "$status" = active ] || [ "$status" = archived ]; } || fail "metadata incompleta: $id"
    case " $ids " in *" $id "*) fail "id duplicado: $id";; esac; ids="$ids $id"
    grep -F -x 'routing:' "$domain/domain.yml" >/dev/null && grep -F -x '  rules: []' "$domain/domain.yml" >/dev/null || fail "routing no determinista o inválido: $id"
  done
}
migration_plan() {
  init_layout
  [ -e "$VAULT/records" ] || [ -L "$VAULT/records" ] || return 0
  local_dir "$VAULT/records" || fail 'records/ no es un directorio local'
  PLAN_DIR=$(mktemp -d "$VAULT/00_inbox/.pending-plan.XXXXXX") || fail 'no se pudo preparar las propuestas de migración'
  PLAN_LIST=$PLAN_DIR/.files
  : > "$PLAN_LIST"
  for record in "$VAULT"/records/*.md "$VAULT"/records/.[!.]*.md "$VAULT"/records/..?*.md; do
    [ -e "$record" ] || [ -L "$record" ] || continue
    local_file "$record" || { rm -rf "$PLAN_DIR"; fail "registro raíz no es un archivo local: $record"; }
    name=$(basename "$record" .md)
    pending=$VAULT/00_inbox/decisions-pending/$name.md
    if [ -e "$pending" ]; then
      local_file "$pending" || { rm -rf "$PLAN_DIR"; fail "la propuesta existente no es un archivo local: $pending"; }
      continue
    fi
    body=$(sed -n '/^# Decisión pendiente$/,$p' "$LAYOUT/pending-decision.md")
    staged=$PLAN_DIR/$name.md
    { printf '%s\n' '---' "id: \"$(yaml_escape "$name")\"" 'type: pending-decision' 'status: pending' "source: \"$(yaml_escape "records/$(basename "$record")")\"" 'proposed_domain: null' "created: $(date -u +%Y-%m-%d)" "updated: $(date -u +%Y-%m-%d)" 'author: operator' 'sources: []' '---' ''; printf '%s\n' "$body"; } > "$staged" || { rm -rf "$PLAN_DIR"; fail "no se pudo crear la propuesta: $pending"; }
    printf '%s\n' "$name.md" >> "$PLAN_LIST"
  done
  MOVED_LIST=$PLAN_DIR/.moved
  : > "$MOVED_LIST"
  while IFS= read -r proposal; do
    if ! mv "$PLAN_DIR/$proposal" "$VAULT/00_inbox/decisions-pending/$proposal"; then
      while IFS= read -r moved; do mv "$VAULT/00_inbox/decisions-pending/$moved" "$PLAN_DIR/$moved" 2>/dev/null || true; done < "$MOVED_LIST"
      rm -rf "$PLAN_DIR"
      fail 'no se pudieron publicar las propuestas de migración'
    fi
    printf '%s\n' "$proposal" >> "$MOVED_LIST"
  done < "$PLAN_LIST"
  rmdir "$PLAN_DIR" 2>/dev/null || rm -rf "$PLAN_DIR"
}
migration_apply() {
  valid_id "$DOMAIN_ID" || fail '--domain inválido'
  [ -n "$RECORD" ] || fail '--record es obligatorio'
  case "$RECORD" in
    *.md) ;;
    *) fail '--record debe ser el nombre de un archivo Markdown' ;;
  esac
  case "$RECORD" in
    */*|*'\'*) fail '--record no puede incluir rutas' ;;
  esac
  DOMAIN=$VAULT/20_domains/$DOMAIN_ID
  local_dir "$VAULT/20_domains" && local_dir "$DOMAIN" && local_dir "$DOMAIN/records" || fail "dominio inexistente o ruta de destino no local: $DOMAIN_ID"
  SOURCE=$VAULT/records/$RECORD
  local_file "$SOURCE" || fail "registro raíz inexistente o no local: $RECORD"
  DEST=$DOMAIN/records/$RECORD
  [ ! -e "$DEST" ] || fail "destino existente: $DEST"
  ACTION_LOG=$VAULT/_indexes/action-log.md
  local_file "$ACTION_LOG" || fail "falta el registro de acciones local: $ACTION_LOG"
  mv "$SOURCE" "$DEST" || fail "no se pudo mover el registro: $RECORD"
  if ! printf '%s | migration-apply | %s | records/%s | 20_domains/%s/records/%s | operator\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$DOMAIN_ID" "$RECORD" "$DOMAIN_ID" "$RECORD" >> "$ACTION_LOG"; then
    mv "$DEST" "$SOURCE" || fail "no se pudo registrar la migración y la reversión también falló: $RECORD"
    fail "no se pudo registrar la migración; el movimiento fue revertido: $RECORD"
  fi
}
# El archivo se crea exclusivamente; queda como evidencia si el proceso falla.
LOCK=$VAULT/.local-mem.lock
case "$COMMAND" in
  init-layout|create-domain|migration-plan|migration-apply)
    ( set -C; : > "$LOCK" ) 2>/dev/null || fail 'vault bloqueada; revisa .local-mem.lock antes de continuar'
    printf 'operation: %s\npid: %s\nhost: %s\ndomain: %s\nrecord: %s\nstage: execute\n' "$COMMAND" "$$" "$(hostname)" "$DOMAIN_ID" "$RECORD" > "$LOCK" || fail 'no se pudo registrar el plan; revisa .local-mem.lock'
    case "$COMMAND" in
      init-layout) printf '%s\n' 'paths: estructura y plantillas de la vault' >> "$LOCK" ;;
      create-domain) printf '%s\n' "paths: 20_domains/$DOMAIN_ID y estructura básica" >> "$LOCK" ;;
      migration-plan) printf '%s\n' 'paths: 00_inbox/decisions-pending y estructura básica' >> "$LOCK" ;;
      migration-apply) printf '%s\n' "paths: records/$RECORD, 20_domains/$DOMAIN_ID/records/$RECORD, _indexes/action-log.md" >> "$LOCK" ;;
    esac || fail 'no se pudo registrar el plan; revisa .local-mem.lock'
    ;;
esac
case "$COMMAND" in
  init-layout) init_layout ;;
  create-domain) create_domain ;;
  check) check_vault; printf '%s\n' 'vault.state: valid' ;;
  migration-plan) migration_plan ;;
  migration-apply) migration_apply ;;
  *) fail "comando desconocido: $COMMAND" ;;
esac


case "$COMMAND" in
  init-layout|create-domain|migration-plan|migration-apply) rm "$LOCK" || fail 'no se pudo liberar .local-mem.lock' ;;
esac
