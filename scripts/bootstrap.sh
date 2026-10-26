#!/bin/sh

set -eu

TARGET=''
MODE=''
INTEGRATE_CODEX=false
FINALIZE=false

select_mode() {
  [ -z "$MODE" ] || fail 'solo se puede seleccionar una operación'
  MODE=$1
}

usage() {
  cat <<'EOF'
Uso: bootstrap.sh --target RUTA_DEL_PROYECTO

Crea o valida una instancia híbrida de ato-ai-skill-mem en RUTA_DEL_PROYECTO/mem.
Este comando nunca modifica RUTA_DEL_PROYECTO/AGENTS.md.

Opciones:
  --status              Informa la alineación entre el release fuente y el vault.
  --update-vault        Actualiza el manifiesto de un vault compatible existente.
  --migrate-workspace-to-vault
                        Migra explícitamente mem/workspace a mem/vault.
  --migrate-vault-format
                        Prepara la migración explícita de formato 2 a formato 3.
  --finalize            Finaliza --migrate-vault-format tras resolver registros raíz.
  --source-status       Informa la alineación del vault del repositorio fuente.
  --update-source-vault
                        Actualiza el manifiesto del vault fuente desde un release.
  --migrate-source-workspace-to-vault
                        Migra explícitamente workspace/ a vault/.
  --integrate-codex    Crea o valida el adaptador local de Codex del proyecto.
EOF
}

fail() {
  printf '%s\n' "error: $*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)
      [ "$#" -ge 2 ] || fail '--target requiere una ruta'
      TARGET=$2
      shift 2
      ;;
    --status)
      select_mode 'status'
      shift
      ;;
    --update-vault)
      select_mode 'update-vault'
      shift
      ;;
    --migrate-workspace-to-vault)
      select_mode 'migrate-workspace-to-vault'
      shift
      ;;
    --migrate-vault-format)
      select_mode 'migrate-vault-format'
      shift
      ;;
    --finalize)
      FINALIZE=true
      shift
      ;;
    --source-status)
      select_mode 'source-status'
      shift
      ;;
    --update-source-vault)
      select_mode 'update-source-vault'
      shift
      ;;
    --migrate-source-workspace-to-vault)
      select_mode 'migrate-source-workspace-to-vault'
      shift
      ;;
    --integrate-codex)
      INTEGRATE_CODEX=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "argumento desconocido: $1"
      ;;
  esac
done

[ -n "$MODE" ] || MODE='bootstrap'
[ "$INTEGRATE_CODEX" = false ] || [ "$MODE" = 'bootstrap' ] || fail '--integrate-codex solo se admite durante la instalación'
[ "$FINALIZE" = false ] || [ "$MODE" = 'migrate-vault-format' ] || fail '--finalize solo se admite con --migrate-vault-format'

case "$MODE" in
  source-status|update-source-vault|migrate-source-workspace-to-vault)
    [ -z "$TARGET" ] || fail "$MODE no admite --target"
    ;;
  *)
    [ -n "$TARGET" ] || fail '--target es obligatorio'
    [ -d "$TARGET" ] || fail "el destino no es un directorio: $TARGET"
    ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
SOURCE_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
if [ "$MODE" = 'source-status' ] || [ "$MODE" = 'update-source-vault' ] || [ "$MODE" = 'migrate-source-workspace-to-vault' ]; then
  TARGET_ROOT=''
  MEM_DIR=''
  WORKSPACE=$SOURCE_ROOT/vault
  LEGACY_WORKSPACE=$SOURCE_ROOT/workspace
  EXPECTED_WORKSPACE_KIND='source'
else
  TARGET_ROOT=$(CDPATH= cd -- "$TARGET" && pwd -P)
  [ "$TARGET_ROOT" != "$SOURCE_ROOT" ] || fail 'la raíz de la fuente no es un proyecto consumidor; usa --source-status'
  MEM_DIR=$TARGET_ROOT/mem
  WORKSPACE=$MEM_DIR/vault
  LEGACY_WORKSPACE=$MEM_DIR/workspace
  EXPECTED_WORKSPACE_KIND='consumer'
  INTEGRATION_CONFIG=$TARGET_ROOT/.ato-ai-skill-mem.yml
  CODEX_ADAPTER_DIR=$TARGET_ROOT/.agents/skills/ato-ai-project-mem
fi

for required in SKILL.md VERSION VAULT_FORMAT references templates scripts scripts/vault.sh templates/vault/SKILL-VERSION.yml templates/vault-layout/AGENTS.md templates/integrations/host-config.yml templates/integrations/codex/SKILL.md; do
  [ -e "$SOURCE_ROOT/$required" ] || fail "falta el componente canónico $required en $SOURCE_ROOT"
done

SKILL_VERSION=$(tr -d '[:space:]' < "$SOURCE_ROOT/VERSION")
if ! printf '%s\n' "$SKILL_VERSION" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' >/dev/null; then
  fail "VERSION debe contener una versión semántica numérica (X.Y.Z)"
fi
CURRENT_VAULT_FORMAT=$(tr -d '[:space:]' < "$SOURCE_ROOT/VAULT_FORMAT")
if ! printf '%s\n' "$CURRENT_VAULT_FORMAT" | grep -E '^[1-9][0-9]*$' >/dev/null; then
  fail "VAULT_FORMAT debe contener un entero positivo"
fi
EXPECTED_TAG="v$SKILL_VERSION"
SOURCE_REVISION=$(git -C "$SOURCE_ROOT" rev-parse HEAD 2>/dev/null || printf 'unknown')
SOURCE_BRANCH=$(git -C "$SOURCE_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'detached-or-unavailable')
MASTER_REVISION=$(git -C "$SOURCE_ROOT" rev-parse master 2>/dev/null || printf 'unavailable')
TAG_REVISION=$(git -C "$SOURCE_ROOT" rev-list -n 1 "$EXPECTED_TAG" 2>/dev/null || printf 'unavailable')
SOURCE_WORKTREE_DIRTY=$(git -C "$SOURCE_ROOT" status --porcelain 2>/dev/null || printf 'unknown')
SOURCE_TAG='unreleased'
SOURCE_STATE='not-release-aligned'
if [ "$SOURCE_BRANCH" = 'master' ] && [ "$SOURCE_REVISION" = "$MASTER_REVISION" ] && [ "$SOURCE_REVISION" = "$TAG_REVISION" ] && [ -z "$SOURCE_WORKTREE_DIRTY" ]; then
  SOURCE_TAG=$EXPECTED_TAG
  SOURCE_STATE='release-aligned'
fi

VERSION_FILE=$WORKSPACE/.ato-ai-skill-mem-version.yml
if [ ! -d "$WORKSPACE" ] && [ -f "$LEGACY_WORKSPACE/.ato-ai-skill-mem-version.yml" ]; then
  VERSION_FILE=$LEGACY_WORKSPACE/.ato-ai-skill-mem-version.yml
fi
INTEGRATION_TEMPLATE=$SOURCE_ROOT/templates/integrations/host-config.yml
CODEX_ADAPTER_TEMPLATE=$SOURCE_ROOT/templates/integrations/codex/SKILL.md

read_marker() {
  marker_key=$1
  sed -n "s/^$marker_key: *//p" "$VERSION_FILE" | sed -n '1p' | tr -d '"'
}

marker_key_count() {
  awk -F: -v key="$1" '$1 == key { count++ } END { print count + 0 }' "$VERSION_FILE"
}

marker_vault_format() {
  if [ ! -f "$VERSION_FILE" ]; then
    printf '%s\n' '1'
    return
  fi
  marker_format=$(read_marker vault_format)
  [ -n "$marker_format" ] || marker_format=$(read_marker workspace_format)
  if [ -z "$marker_format" ]; then
    printf '%s\n' '1'
  else
    printf '%s\n' "$marker_format"
  fi
}

marker_vault_kind() {
  if [ ! -f "$VERSION_FILE" ]; then
    printf '%s\n' 'consumer'
    return
  fi
  marker_kind=$(read_marker vault_kind)
  [ -n "$marker_kind" ] || marker_kind=$(read_marker workspace_kind)
  if [ -z "$marker_kind" ]; then
    printf '%s\n' 'consumer'
  else
    printf '%s\n' "$marker_kind"
  fi
}

vault_data_compatibility() {
  if [ ! -d "$WORKSPACE" ]; then
    if [ -d "$LEGACY_WORKSPACE" ]; then
      printf '%s\n' 'migration-required'
      return
    fi
    printf '%s\n' 'absent'
  elif [ "$(marker_vault_format)" = "$CURRENT_VAULT_FORMAT" ] && [ -n "$(read_marker vault_format 2>/dev/null || true)" ]; then
    printf '%s\n' 'compatible'
  else
    printf '%s\n' 'migration-required'
  fi
}

version_relation() {
  workspace_version=$1
  awk -v source="$SKILL_VERSION" -v workspace="$workspace_version" 'BEGIN {
    split(source, s, "."); split(workspace, w, ".");
    for (i = 1; i <= 3; i++) {
      if ((s[i] + 0) > (w[i] + 0)) { print "source-newer"; exit }
      if ((s[i] + 0) < (w[i] + 0)) { print "workspace-newer"; exit }
    }
    print "same"
  }'
}

vault_state() {
  if [ ! -d "$WORKSPACE" ]; then
    if [ -d "$LEGACY_WORKSPACE" ]; then
      printf '%s\n' 'migration-required'
      return
    fi
    printf '%s\n' 'absent'
  elif [ ! -f "$VERSION_FILE" ]; then
    printf '%s\n' 'legacy-compatible'
  elif [ "$(marker_vault_kind)" != "$EXPECTED_WORKSPACE_KIND" ]; then
    printf '%s\n' 'role-mismatch'
  elif [ "$(vault_data_compatibility)" != 'compatible' ]; then
    printf '%s\n' 'migration-required'
  elif [ "$(read_marker skill_version)" != "$SKILL_VERSION" ]; then
    case "$(version_relation "$(read_marker skill_version)")" in
      source-newer) printf '%s\n' 'compatible-update-available' ;;
    workspace-newer) printf '%s\n' 'vault-newer' ;;
      *) printf '%s\n' 'version-mismatch' ;;
    esac
  else
    printf '%s\n' 'aligned'
  fi
}

render_marker() {
  marker_created_at=$1
  marker_destination=$2
  marker_date=$(date -u +%Y-%m-%d)
  sed \
    -e "s/^vault_kind: .*/vault_kind: $EXPECTED_WORKSPACE_KIND/" \
    -e "s/^skill_version: .*/skill_version: $SKILL_VERSION/" \
    -e "s/^vault_format: .*/vault_format: $CURRENT_VAULT_FORMAT/" \
    -e "s/^source_revision: .*/source_revision: $SOURCE_REVISION/" \
    -e "s/^source_tag: .*/source_tag: $SOURCE_TAG/" \
    -e "s/^created_at: .*/created_at: $marker_created_at/" \
    -e "s/^updated_at: .*/updated_at: $marker_date/" \
    "$SOURCE_ROOT/templates/vault/SKILL-VERSION.yml" > "$marker_destination"
}

write_marker() {
  render_marker "$1" "$VERSION_FILE"
}

codex_adapter_is_managed() {
  [ -d "$CODEX_ADAPTER_DIR" ] && [ ! -L "$CODEX_ADAPTER_DIR" ] || return 1
  [ -f "$CODEX_ADAPTER_DIR/SKILL.md" ] && [ ! -L "$CODEX_ADAPTER_DIR/SKILL.md" ] || return 1
  cmp -s "$CODEX_ADAPTER_DIR/SKILL.md" "$CODEX_ADAPTER_TEMPLATE" || return 1
  [ "$(find "$CODEX_ADAPTER_DIR" -mindepth 1 -maxdepth 1 -print | wc -l | tr -d '[:space:]')" = 1 ]
}

codex_integration_state() {
  [ ! -e "$INTEGRATION_CONFIG" ] && [ ! -L "$INTEGRATION_CONFIG" ] && { printf '%s\n' 'not-configured'; return; }
  [ -f "$INTEGRATION_CONFIG" ] && [ ! -L "$INTEGRATION_CONFIG" ] || { printf '%s\n' 'unsupported-config'; return; }
  cmp -s "$INTEGRATION_CONFIG" "$INTEGRATION_TEMPLATE" || { printf '%s\n' 'unsupported-config'; return; }
  [ -d "$CODEX_ADAPTER_DIR" ] || { printf '%s\n' 'adapter-missing'; return; }
  codex_adapter_is_managed && printf '%s\n' 'aligned' || printf '%s\n' 'conflict'
}

validate_codex_integration() {
  if { [ -e "$INTEGRATION_CONFIG" ] || [ -L "$INTEGRATION_CONFIG" ]; } && { [ ! -f "$INTEGRATION_CONFIG" ] || [ -L "$INTEGRATION_CONFIG" ] || ! cmp -s "$INTEGRATION_CONFIG" "$INTEGRATION_TEMPLATE"; }; then
    fail "la configuración de integración no coincide: $INTEGRATION_CONFIG"
  fi
  for path in "$TARGET_ROOT/.agents" "$TARGET_ROOT/.agents/skills"; do
    { [ ! -e "$path" ] && [ ! -L "$path" ]; } || { [ -d "$path" ] && [ ! -L "$path" ]; } || fail "la ruta de integración no es un directorio local: $path"
  done
  if { [ -e "$CODEX_ADAPTER_DIR" ] || [ -L "$CODEX_ADAPTER_DIR" ]; } && ! codex_adapter_is_managed; then
    fail "el adaptador de Codex existente no está administrado: $CODEX_ADAPTER_DIR"
  fi
}

install_codex_integration() {
  mkdir -p "$CODEX_ADAPTER_DIR"
  { [ -e "$INTEGRATION_CONFIG" ] || [ -L "$INTEGRATION_CONFIG" ]; } || cp "$INTEGRATION_TEMPLATE" "$INTEGRATION_CONFIG"
  { [ -e "$CODEX_ADAPTER_DIR/SKILL.md" ] || [ -L "$CODEX_ADAPTER_DIR/SKILL.md" ]; } || cp "$CODEX_ADAPTER_TEMPLATE" "$CODEX_ADAPTER_DIR/SKILL.md"
}

print_status() {
  printf 'source.version: %s\n' "$SKILL_VERSION"
  printf 'source.expected_tag: %s\n' "$EXPECTED_TAG"
  printf 'source.branch: %s\n' "$SOURCE_BRANCH"
  printf 'source.revision: %s\n' "$SOURCE_REVISION"
  printf 'source.state: %s\n' "$SOURCE_STATE"
  printf 'vault.format: %s\n' "$(marker_vault_format)"
  printf 'vault.expected_format: %s\n' "$CURRENT_VAULT_FORMAT"
  printf 'vault.data_compatibility: %s\n' "$(vault_data_compatibility)"
  printf 'vault.kind: %s\n' "$(marker_vault_kind)"
  printf 'vault.expected_kind: %s\n' "$EXPECTED_WORKSPACE_KIND"
  printf 'vault.state: %s\n' "$(vault_state)"
  if [ "$EXPECTED_WORKSPACE_KIND" = 'consumer' ]; then
    printf 'integration.codex.state: %s\n' "$(codex_integration_state)"
    printf 'integration.codex.adapter_path: %s\n' '.agents/skills/ato-ai-project-mem'
  fi
  if [ -f "$VERSION_FILE" ]; then
    printf 'vault.skill_version: %s\n' "$(read_marker skill_version)"
    printf 'vault.source_revision: %s\n' "$(read_marker source_revision)"
    printf 'vault.source_tag: %s\n' "$(read_marker source_tag)"
    printf 'vault.created_at: %s\n' "$(read_marker created_at)"
    printf 'vault.updated_at: %s\n' "$(read_marker updated_at)"
  fi
}

migrate_workspace_to_vault() {
  [ -d "$LEGACY_WORKSPACE" ] || fail "no existe el almacenamiento heredado: $LEGACY_WORKSPACE"
  [ ! -e "$WORKSPACE" ] || fail "no se puede migrar: ya existe el destino $WORKSPACE"
  OLD_VERSION_FILE=$LEGACY_WORKSPACE/.ato-ai-skill-mem-version.yml
  [ -f "$OLD_VERSION_FILE" ] || fail 'la migración requiere el manifiesto heredado'
  OLD_FORMAT=$(sed -n 's/^workspace_format: *//p' "$OLD_VERSION_FILE" | sed -n '1p')
  [ -n "$OLD_FORMAT" ] || OLD_FORMAT=1
  [ "$OLD_FORMAT" = '1' ] || fail "el formato heredado no es migrable: $OLD_FORMAT"
  CREATED_AT=$(sed -n 's/^created_at: *//p' "$OLD_VERSION_FILE" | sed -n '1p' | tr -d '"')
  [ -n "$CREATED_AT" ] || CREATED_AT=unknown
  MARKER_TMP=$(mktemp "$SOURCE_ROOT/.ato-ai-vault-marker.XXXXXX")
  write_marker_to() {
    DESTINATION=$1
    sed -e "s/^vault_kind: .*/vault_kind: $EXPECTED_WORKSPACE_KIND/" \
      -e "s/^skill_version: .*/skill_version: $SKILL_VERSION/" \
      -e "s/^vault_format: .*/vault_format: $CURRENT_VAULT_FORMAT/" \
      -e "s/^source_revision: .*/source_revision: $SOURCE_REVISION/" \
      -e "s/^source_tag: .*/source_tag: $SOURCE_TAG/" \
      -e "s/^created_at: .*/created_at: $CREATED_AT/" \
      -e "s/^updated_at: .*/updated_at: $(date -u +%Y-%m-%d)/" \
      "$SOURCE_ROOT/templates/vault/SKILL-VERSION.yml" > "$DESTINATION"
  }
  write_marker_to "$MARKER_TMP"
  if ! mv "$LEGACY_WORKSPACE" "$WORKSPACE"; then
    rm -f "$MARKER_TMP"
    fail 'no se pudo mover el almacenamiento heredado'
  fi
  VERSION_FILE=$WORKSPACE/.ato-ai-skill-mem-version.yml
  if ! mv "$MARKER_TMP" "$VERSION_FILE"; then
    mv "$WORKSPACE" "$LEGACY_WORKSPACE"
    rm -f "$MARKER_TMP"
    fail 'no se pudo actualizar el manifiesto; la migración fue revertida'
  fi
  printf 'migración completada: %s -> %s\n' "$LEGACY_WORKSPACE" "$WORKSPACE"
}

finalization_layout_ready() {
  [ -f "$WORKSPACE/AGENTS.md" ] && [ ! -L "$WORKSPACE/AGENTS.md" ] || return 1
  for dir in 00_inbox 10_areas 20_domains 30_resources 40_archive 50_daily 60_exports _indexes _maps _templates; do [ -d "$WORKSPACE/$dir" ] && [ ! -L "$WORKSPACE/$dir" ] || return 1; done
  for file in _indexes/INDEX.md _indexes/action-log.md _maps/INDEX.md; do [ -f "$WORKSPACE/$file" ] && [ ! -L "$WORKSPACE/$file" ] || return 1; done
  return 0
}

root_records_pending() {
  [ -d "$WORKSPACE/records" ] && find "$WORKSPACE/records" -mindepth 1 -maxdepth 1 -print -quit | grep -q .
}

migrate_vault_format() {
  [ -d "$WORKSPACE" ] || fail 'la migración de formato requiere una vault existente'
  [ ! -d "$LEGACY_WORKSPACE" ] || fail 'existe mem/workspace; ejecuta --migrate-workspace-to-vault explícitamente'
  [ -f "$VERSION_FILE" ] || fail 'la migración de formato requiere un manifiesto de formato 2'
  [ "$(marker_key_count vault_format)" = 1 ] && [ "$(marker_key_count vault_kind)" = 1 ] || fail 'el manifiesto de formato 2 es ambiguo'
  [ "$(read_marker vault_format)" = 2 ] || fail 'la migración de formato solo admite vault_format: 2'
  [ "$(read_marker vault_kind)" = consumer ] || fail 'la migración de formato solo admite vault_kind: consumer'
  if [ "$FINALIZE" = false ]; then
    sh "$SOURCE_ROOT/scripts/vault.sh" migration-plan --vault "$WORKSPACE"
    printf 'migración de formato preparada: resuelve los registros raíz y ejecuta --migrate-vault-format --finalize\n'
    return
  fi
  finalization_layout_ready || fail 'la finalización requiere una migración de formato previamente preparada'
  root_records_pending && fail "la migración de formato tiene contenido pendiente en records/: $(find "$WORKSPACE/records" -mindepth 1 -maxdepth 1 -print -quit)"
  LEGACY_INDEX=$WORKSPACE/INDEX.md
  ARCHIVED_INDEX=$WORKSPACE/40_archive/legacy-root-INDEX.md
  [ ! -e "$LEGACY_INDEX" ] || [ ! -e "$ARCHIVED_INDEX" ] || fail "el índice legado ya existe en el archivo: $ARCHIVED_INDEX"
  CREATED_AT=$(read_marker created_at 2>/dev/null || printf unknown)
  [ -n "$CREATED_AT" ] || CREATED_AT=unknown
  MARKER_TMP=$(mktemp "$WORKSPACE/.ato-ai-vault-marker.XXXXXX") || fail 'no se pudo preparar el manifiesto de formato 3'
  if ! render_marker "$CREATED_AT" "$MARKER_TMP"; then
    rm -f "$MARKER_TMP"
    fail 'no se pudo preparar el manifiesto de formato 3'
  fi
  MOVED_INDEX=false
  if [ -e "$LEGACY_INDEX" ]; then
    if ! mv "$LEGACY_INDEX" "$ARCHIVED_INDEX"; then
      rm -f "$MARKER_TMP"
      fail 'no se pudo archivar el índice legado'
    fi
    MOVED_INDEX=true
  fi
  if ! mv "$MARKER_TMP" "$VERSION_FILE"; then
    [ "$MOVED_INDEX" = false ] || mv "$ARCHIVED_INDEX" "$LEGACY_INDEX" || fail 'no se pudo escribir el manifiesto y la reversión del índice también falló'
    rm -f "$MARKER_TMP"
    fail 'no se pudo escribir el manifiesto; la migración fue revertida'
  fi
  printf 'migración de formato completada: vault_format 2 -> 3\n'
}

if [ "$MODE" = 'status' ] || [ "$MODE" = 'source-status' ]; then
  print_status
  exit 0
fi

if [ "$MODE" = 'migrate-workspace-to-vault' ] || [ "$MODE" = 'migrate-source-workspace-to-vault' ]; then
  if [ "$MODE" = 'migrate-workspace-to-vault' ]; then
    [ -e "$MEM_DIR" ] && [ -d "$MEM_DIR" ] || fail "la instancia no es un directorio: $MEM_DIR"
  fi
  migrate_workspace_to_vault
  exit 0
fi

if [ "$MODE" = 'migrate-vault-format' ]; then
  migrate_vault_format
  exit 0
fi

if [ "$MODE" = 'update-source-vault' ]; then
  [ -d "$WORKSPACE" ] || fail 'la actualización del vault fuente requiere vault/'
  [ -f "$VERSION_FILE" ] || fail 'el vault fuente requiere un manifiesto con vault_kind: source'
  [ "$(marker_vault_kind)" = 'source' ] || fail 'el manifiesto no pertenece a un vault de fuente'
  [ "$SOURCE_STATE" = 'release-aligned' ] || fail 'la actualización del vault fuente requiere una fuente release-aligned'
  [ -z "$SOURCE_WORKTREE_DIRTY" ] || fail 'la actualización del vault fuente requiere un checkout limpio'
  [ "$(vault_data_compatibility)" = 'compatible' ] || fail 'el formato del vault requiere una migración confirmada'
  case "$(vault_state)" in
    compatible-update-available|aligned) ;;
    *) fail 'la actualización del vault fuente no avanzaría la versión registrada del skill' ;;
  esac
  CREATED_AT=$(read_marker created_at 2>/dev/null || printf 'unknown')
  [ -n "$CREATED_AT" ] || CREATED_AT='unknown'
  write_marker "$CREATED_AT"
  printf 'vault de fuente actualizado: %s (vault: %s)\n' "$WORKSPACE" "$(vault_state)"
  exit 0
fi

if [ -e "$MEM_DIR" ] && [ ! -d "$MEM_DIR" ]; then
  fail "la ruta de instancia existe pero no es un directorio: $MEM_DIR"
fi
if [ -L "$MEM_DIR" ]; then
  fail "el directorio de instancia debe ser local, no un enlace simbólico: $MEM_DIR"
fi

if [ "$MODE" = 'update-vault' ] && [ ! -d "$WORKSPACE" ]; then
  fail "la actualización del vault requiere una instancia existente"
fi

if [ "$MODE" = 'update-vault' ] && [ "$SOURCE_STATE" != 'release-aligned' ]; then
  fail "la actualización del vault requiere una fuente release-aligned"
fi
if [ "$MODE" = 'update-vault' ] && [ -d "$WORKSPACE" ] && [ "$(vault_data_compatibility)" != 'compatible' ]; then
  fail "el formato del vault requiere una migración confirmada"
fi
if [ -f "$VERSION_FILE" ] && [ "$(marker_vault_kind)" != 'consumer' ]; then
  fail 'el manifiesto no pertenece a un vault de consumidor'
fi
[ ! -d "$LEGACY_WORKSPACE" ] || fail 'existe mem/workspace; ejecuta --migrate-workspace-to-vault explícitamente'
if [ "$INTEGRATE_CODEX" = true ]; then
  validate_codex_integration
fi
if [ "$MODE" = 'update-vault' ]; then
  case "$(vault_state)" in
    legacy-compatible|compatible-update-available|aligned) ;;
    *) fail "la actualización del vault no avanzaría la versión registrada del skill" ;;
  esac
fi

validate_link_destination() {
  source=$1
  destination=$2

  if [ -L "$destination" ]; then
    actual=$(readlink "$destination")
    [ "$actual" = "$source" ] || fail "el enlace existente difiere: $destination -> $actual"
    return
  fi

  if [ -e "$destination" ]; then
    fail "no se puede reemplazar una ruta existente que no es enlace: $destination"
  fi
}

ensure_link() {
  source=$1
  destination=$2

  if [ -L "$destination" ]; then
    return
  fi

  if ! ln -s "$source" "$destination"; then
    fail "no se pudo crear el enlace simbólico $destination; habilita permisos para enlaces simbólicos en vez de copiar el skill"
  fi
}

for linked_item in SKILL.md VERSION VAULT_FORMAT references templates scripts; do
  validate_link_destination "$SOURCE_ROOT/$linked_item" "$MEM_DIR/$linked_item"
done

mkdir -p "$MEM_DIR"
for linked_item in SKILL.md VERSION VAULT_FORMAT references templates scripts; do
  ensure_link "$SOURCE_ROOT/$linked_item" "$MEM_DIR/$linked_item"
done

WORKSPACE_EXISTED=false
[ -d "$WORKSPACE" ] && WORKSPACE_EXISTED=true
mkdir -p "$WORKSPACE"
sh "$SOURCE_ROOT/scripts/vault.sh" init-layout --vault "$WORKSPACE"

if [ "$MODE" = 'update-vault' ] || [ ! -f "$VERSION_FILE" ]; then
  CREATED_AT=$(date -u +%Y-%m-%d)
  if [ "$WORKSPACE_EXISTED" = true ]; then
    CREATED_AT=$(read_marker created_at 2>/dev/null || printf 'unknown')
    [ -n "$CREATED_AT" ] || CREATED_AT='unknown'
  fi
  write_marker "$CREATED_AT"
fi

if [ "$INTEGRATE_CODEX" = true ]; then
  install_codex_integration
fi

printf 'instancia de memoria lista: %s (vault: %s)\n' "$MEM_DIR" "$(vault_state)"
