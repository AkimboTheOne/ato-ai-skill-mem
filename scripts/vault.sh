#!/bin/sh

set -eu

COMMAND=${1:-}
[ -n "$COMMAND" ] || { printf '%s\n' 'uso: vault.sh <init-layout|create-domain|check|migration-plan|migration-apply> --vault RUTA [...]' >&2; exit 1; }
shift

fail() { printf '%s\n' "error: $*" >&2; exit 1; }
require_value() {
  [ "$#" -ge 2 ] || fail "$1 requiere un valor"
  case "$2" in
    --*) fail "$1 requiere un valor" ;;
  esac
}

VAULT=''
DOMAIN_ID=''
DOMAIN_TITLE=''
RECORD=''
TITLE_SET=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --vault) require_value "$@"; VAULT=$2; shift 2 ;;
    --id|--domain) require_value "$@"; DOMAIN_ID=$2; shift 2 ;;
    --title) require_value "$@"; DOMAIN_TITLE=$2; TITLE_SET=true; shift 2 ;;
    --record) require_value "$@"; RECORD=$2; shift 2 ;;
    *) printf '%s\n' "error: argumento desconocido: $1" >&2; exit 1 ;;
  esac
done
[ -n "$VAULT" ] || { printf '%s\n' 'error: --vault es obligatorio' >&2; exit 1; }
[ -d "$VAULT" ] || { printf '%s\n' "error: la vault no existe: $VAULT" >&2; exit 1; }
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
SOURCE_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
LAYOUT=$SOURCE_ROOT/templates/vault-layout

valid_id() { printf '%s\n' "$1" | grep -E '^[a-z0-9][a-z0-9-]{0,62}$' >/dev/null; }
local_file() { [ -f "$1" ] && [ ! -L "$1" ]; }
local_dir() { [ -d "$1" ] && [ ! -L "$1" ]; }
copy_if_missing() { [ -e "$2" ] || cp "$1" "$2"; }
yaml_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
single_line() { [ "$(printf '%s\n' "$1" | wc -l | tr -d '[:space:]')" = 1 ]; }
init_layout() {
  for dir in 00_inbox/decisions-pending 10_areas 20_domains 30_resources 40_archive 50_daily 60_exports _indexes _maps _templates; do mkdir -p "$VAULT/$dir"; done
  copy_if_missing "$LAYOUT/AGENTS.md" "$VAULT/AGENTS.md"
  for name in domain.yml domain-AGENTS.md domain-INDEX.md area.md daily.md pending-decision.md export.md; do copy_if_missing "$LAYOUT/$name" "$VAULT/_templates/$name"; done
  [ -e "$VAULT/_indexes/INDEX.md" ] || printf '# Índices de la vault\n' > "$VAULT/_indexes/INDEX.md"
  [ -e "$VAULT/_indexes/action-log.md" ] || printf '# Registro de acciones\n\n' > "$VAULT/_indexes/action-log.md"
  [ -e "$VAULT/_maps/INDEX.md" ] || printf '# Mapas de la vault\n' > "$VAULT/_maps/INDEX.md"
}
create_domain() {
  valid_id "$DOMAIN_ID" || fail '--id debe usar minúsculas, dígitos y guiones'
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
    || ! { printf '# Dominio: %s\n' "$DOMAIN_TITLE"; sed '1d' "$LAYOUT/domain-AGENTS.md"; } > "$TMP_DOMAIN/AGENTS.md" \
    || ! cp "$LAYOUT/domain-INDEX.md" "$TMP_DOMAIN/INDEX.md" \
    || ! mv "$TMP_DOMAIN" "$DOMAIN"; then
    rm -rf "$TMP_DOMAIN"
    fail "no se pudo crear el dominio: $DOMAIN_ID"
  fi
}
check_vault() {
  local_file "$VAULT/AGENTS.md" || fail 'falta archivo local vault/AGENTS.md'
  [ ! -e "$VAULT/INDEX.md" ] || fail 'INDEX.md raíz heredado; archívalo antes de validar formato 3'
  for dir in 00_inbox 10_areas 20_domains 30_resources 40_archive 50_daily 60_exports _indexes _maps _templates; do local_dir "$VAULT/$dir" || fail "falta directorio local: $dir"; done
  for file in _indexes/INDEX.md _indexes/action-log.md _maps/INDEX.md; do local_file "$VAULT/$file" || fail "falta archivo canónico local: $file"; done
  for file in domain.yml domain-AGENTS.md domain-INDEX.md area.md daily.md pending-decision.md export.md; do local_file "$VAULT/_templates/$file" || fail "falta plantilla canónica local: $file"; done
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
    { printf '%s\n' '---' "id: \"$(yaml_escape "$name")\"" 'status: pending' "source: \"$(yaml_escape "records/$(basename "$record")")\"" 'proposed_domain: null' "created: $(date -u +%Y-%m-%d)" '---' ''; printf '%s\n' "$body"; } > "$staged" || { rm -rf "$PLAN_DIR"; fail "no se pudo crear la propuesta: $pending"; }
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
  [ -d "$DOMAIN/records" ] || fail "dominio inexistente: $DOMAIN_ID"
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
case "$COMMAND" in
  init-layout) init_layout ;;
  create-domain) create_domain ;;
  check) check_vault ;;
  migration-plan) migration_plan ;;
  migration-apply) migration_apply ;;
  *) fail "comando desconocido: $COMMAND" ;;
esac

