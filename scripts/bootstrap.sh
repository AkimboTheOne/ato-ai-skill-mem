#!/bin/sh

set -eu

TARGET=''
MODE=''
INTEGRATE_CODEX=false

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
  --status              Informa la alineación entre el release fuente y el workspace.
  --update-workspace    Actualiza el manifiesto de un workspace compatible existente.
  --source-status       Informa la alineación del workspace del repositorio fuente.
  --update-source-workspace
                        Actualiza el manifiesto del workspace fuente desde un release.
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
    --update-workspace)
      select_mode 'update-workspace'
      shift
      ;;
    --source-status)
      select_mode 'source-status'
      shift
      ;;
    --update-source-workspace)
      select_mode 'update-source-workspace'
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

case "$MODE" in
  source-status|update-source-workspace)
    [ -z "$TARGET" ] || fail "$MODE no admite --target"
    ;;
  *)
    [ -n "$TARGET" ] || fail '--target es obligatorio'
    [ -d "$TARGET" ] || fail "el destino no es un directorio: $TARGET"
    ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
SOURCE_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
if [ "$MODE" = 'source-status' ] || [ "$MODE" = 'update-source-workspace' ]; then
  TARGET_ROOT=''
  MEM_DIR=''
  WORKSPACE=$SOURCE_ROOT/workspace
  EXPECTED_WORKSPACE_KIND='source'
else
  TARGET_ROOT=$(CDPATH= cd -- "$TARGET" && pwd -P)
  [ "$TARGET_ROOT" != "$SOURCE_ROOT" ] || fail 'la raíz de la fuente no es un proyecto consumidor; usa --source-status'
  MEM_DIR=$TARGET_ROOT/mem
  WORKSPACE=$MEM_DIR/workspace
  EXPECTED_WORKSPACE_KIND='consumer'
  INTEGRATION_CONFIG=$TARGET_ROOT/.ato-ai-skill-mem.yml
  CODEX_ADAPTER_DIR=$TARGET_ROOT/.agents/skills/ato-ai-project-mem
fi

for required in SKILL.md VERSION WORKSPACE_FORMAT references templates scripts templates/integrations/host-config.yml templates/integrations/codex/SKILL.md; do
  [ -e "$SOURCE_ROOT/$required" ] || fail "falta el componente canónico $required en $SOURCE_ROOT"
done

SKILL_VERSION=$(tr -d '[:space:]' < "$SOURCE_ROOT/VERSION")
if ! printf '%s\n' "$SKILL_VERSION" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' >/dev/null; then
  fail "VERSION debe contener una versión semántica numérica (X.Y.Z)"
fi
CURRENT_WORKSPACE_FORMAT=$(tr -d '[:space:]' < "$SOURCE_ROOT/WORKSPACE_FORMAT")
if ! printf '%s\n' "$CURRENT_WORKSPACE_FORMAT" | grep -E '^[1-9][0-9]*$' >/dev/null; then
  fail "WORKSPACE_FORMAT debe contener un entero positivo"
fi
EXPECTED_TAG="v$SKILL_VERSION"
SOURCE_REVISION=$(git -C "$SOURCE_ROOT" rev-parse HEAD 2>/dev/null || printf 'unknown')
SOURCE_BRANCH=$(git -C "$SOURCE_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'detached-or-unavailable')
MASTER_REVISION=$(git -C "$SOURCE_ROOT" rev-parse master 2>/dev/null || printf 'unavailable')
TAG_REVISION=$(git -C "$SOURCE_ROOT" rev-list -n 1 "$EXPECTED_TAG" 2>/dev/null || printf 'unavailable')
SOURCE_DIRTY=$(git -C "$SOURCE_ROOT" status --porcelain -- AGENTS.md README.md SKILL.md VERSION WORKSPACE_FORMAT references templates scripts 2>/dev/null || printf 'unknown')
SOURCE_WORKTREE_DIRTY=$(git -C "$SOURCE_ROOT" status --porcelain 2>/dev/null || printf 'unknown')
SOURCE_TAG='unreleased'
SOURCE_STATE='not-release-aligned'
if [ "$SOURCE_BRANCH" = 'master' ] && [ "$SOURCE_REVISION" = "$MASTER_REVISION" ] && [ "$SOURCE_REVISION" = "$TAG_REVISION" ] && [ -z "$SOURCE_DIRTY" ]; then
  SOURCE_TAG=$EXPECTED_TAG
  SOURCE_STATE='release-aligned'
fi

VERSION_FILE=$WORKSPACE/.ato-ai-skill-mem-version.yml
INTEGRATION_TEMPLATE=$SOURCE_ROOT/templates/integrations/host-config.yml
CODEX_ADAPTER_TEMPLATE=$SOURCE_ROOT/templates/integrations/codex/SKILL.md

read_marker() {
  marker_key=$1
  sed -n "s/^$marker_key: *//p" "$VERSION_FILE" | sed -n '1p' | tr -d '"'
}

marker_workspace_format() {
  if [ ! -f "$VERSION_FILE" ]; then
    printf '%s\n' '1'
    return
  fi
  marker_format=$(read_marker workspace_format)
  if [ -z "$marker_format" ]; then
    printf '%s\n' '1'
  else
    printf '%s\n' "$marker_format"
  fi
}

marker_workspace_kind() {
  if [ ! -f "$VERSION_FILE" ]; then
    printf '%s\n' 'consumer'
    return
  fi
  marker_kind=$(read_marker workspace_kind)
  if [ -z "$marker_kind" ]; then
    printf '%s\n' 'consumer'
  else
    printf '%s\n' "$marker_kind"
  fi
}

workspace_data_compatibility() {
  if [ ! -d "$WORKSPACE" ]; then
    printf '%s\n' 'absent'
  elif [ "$(marker_workspace_format)" = "$CURRENT_WORKSPACE_FORMAT" ]; then
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

workspace_state() {
  if [ ! -d "$WORKSPACE" ]; then
    printf '%s\n' 'absent'
  elif [ ! -f "$VERSION_FILE" ]; then
    printf '%s\n' 'legacy-compatible'
  elif [ "$(marker_workspace_kind)" != "$EXPECTED_WORKSPACE_KIND" ]; then
    printf '%s\n' 'role-mismatch'
  elif [ "$(workspace_data_compatibility)" != 'compatible' ]; then
    printf '%s\n' 'migration-required'
  elif [ "$(read_marker skill_version)" != "$SKILL_VERSION" ]; then
    case "$(version_relation "$(read_marker skill_version)")" in
      source-newer) printf '%s\n' 'compatible-update-available' ;;
      workspace-newer) printf '%s\n' 'workspace-newer' ;;
      *) printf '%s\n' 'version-mismatch' ;;
    esac
  else
    printf '%s\n' 'aligned'
  fi
}

write_marker() {
  marker_created_at=$1
  marker_date=$(date -u +%Y-%m-%d)
  sed \
    -e "s/^workspace_kind: .*/workspace_kind: $EXPECTED_WORKSPACE_KIND/" \
    -e "s/^skill_version: .*/skill_version: $SKILL_VERSION/" \
    -e "s/^workspace_format: .*/workspace_format: $CURRENT_WORKSPACE_FORMAT/" \
    -e "s/^source_revision: .*/source_revision: $SOURCE_REVISION/" \
    -e "s/^source_tag: .*/source_tag: $SOURCE_TAG/" \
    -e "s/^created_at: .*/created_at: $marker_created_at/" \
    -e "s/^updated_at: .*/updated_at: $marker_date/" \
    "$SOURCE_ROOT/templates/workspace/SKILL-VERSION.yml" > "$VERSION_FILE"
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
  printf 'workspace.format: %s\n' "$(marker_workspace_format)"
  printf 'workspace.expected_format: %s\n' "$CURRENT_WORKSPACE_FORMAT"
  printf 'workspace.data_compatibility: %s\n' "$(workspace_data_compatibility)"
  printf 'workspace.kind: %s\n' "$(marker_workspace_kind)"
  printf 'workspace.expected_kind: %s\n' "$EXPECTED_WORKSPACE_KIND"
  printf 'workspace.state: %s\n' "$(workspace_state)"
  if [ "$EXPECTED_WORKSPACE_KIND" = 'consumer' ]; then
    printf 'integration.codex.state: %s\n' "$(codex_integration_state)"
    printf 'integration.codex.adapter_path: %s\n' '.agents/skills/ato-ai-project-mem'
  fi
  if [ -f "$VERSION_FILE" ]; then
    printf 'workspace.skill_version: %s\n' "$(read_marker skill_version)"
    printf 'workspace.source_revision: %s\n' "$(read_marker source_revision)"
    printf 'workspace.source_tag: %s\n' "$(read_marker source_tag)"
    printf 'workspace.created_at: %s\n' "$(read_marker created_at)"
    printf 'workspace.updated_at: %s\n' "$(read_marker updated_at)"
  fi
}

if [ "$MODE" = 'status' ] || [ "$MODE" = 'source-status' ]; then
  print_status
  exit 0
fi

if [ "$MODE" = 'update-source-workspace' ]; then
  [ -d "$WORKSPACE" ] || fail 'la actualización del workspace fuente requiere workspace/'
  [ -f "$VERSION_FILE" ] || fail 'el workspace fuente requiere un manifiesto con workspace_kind: source'
  [ "$(marker_workspace_kind)" = 'source' ] || fail 'el manifiesto no pertenece a un workspace de fuente'
  [ "$SOURCE_STATE" = 'release-aligned' ] || fail 'la actualización del workspace fuente requiere una fuente release-aligned'
  [ -z "$SOURCE_WORKTREE_DIRTY" ] || fail 'la actualización del workspace fuente requiere un checkout limpio'
  [ "$(workspace_data_compatibility)" = 'compatible' ] || fail 'el formato del workspace requiere una migración confirmada'
  case "$(workspace_state)" in
    compatible-update-available|aligned) ;;
    *) fail 'la actualización del workspace fuente no avanzaría la versión registrada del skill' ;;
  esac
  CREATED_AT=$(read_marker created_at 2>/dev/null || printf 'unknown')
  [ -n "$CREATED_AT" ] || CREATED_AT='unknown'
  write_marker "$CREATED_AT"
  printf 'workspace de fuente actualizado: %s (workspace: %s)\n' "$WORKSPACE" "$(workspace_state)"
  exit 0
fi

if [ -e "$MEM_DIR" ] && [ ! -d "$MEM_DIR" ]; then
  fail "la ruta de instancia existe pero no es un directorio: $MEM_DIR"
fi
if [ -L "$MEM_DIR" ]; then
  fail "el directorio de instancia debe ser local, no un enlace simbólico: $MEM_DIR"
fi

if [ "$MODE" = 'update-workspace' ] && [ ! -d "$WORKSPACE" ]; then
  fail "la actualización del workspace requiere una instancia existente"
fi

if [ "$MODE" = 'update-workspace' ] && [ "$SOURCE_STATE" != 'release-aligned' ]; then
  fail "la actualización del workspace requiere una fuente release-aligned"
fi
if [ "$MODE" = 'update-workspace' ] && [ -d "$WORKSPACE" ] && [ "$(workspace_data_compatibility)" != 'compatible' ]; then
  fail "el formato del workspace requiere una migración confirmada"
fi
if [ -f "$VERSION_FILE" ] && [ "$(marker_workspace_kind)" != 'consumer' ]; then
  fail 'el manifiesto no pertenece a un workspace de consumidor'
fi
if [ "$INTEGRATE_CODEX" = true ]; then
  validate_codex_integration
fi
if [ "$MODE" = 'update-workspace' ]; then
  case "$(workspace_state)" in
    legacy-compatible|compatible-update-available|aligned) ;;
    *) fail "la actualización del workspace no avanzaría la versión registrada del skill" ;;
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

for linked_item in SKILL.md VERSION WORKSPACE_FORMAT references templates scripts; do
  validate_link_destination "$SOURCE_ROOT/$linked_item" "$MEM_DIR/$linked_item"
done

mkdir -p "$MEM_DIR"
for linked_item in SKILL.md VERSION WORKSPACE_FORMAT references templates scripts; do
  ensure_link "$SOURCE_ROOT/$linked_item" "$MEM_DIR/$linked_item"
done

WORKSPACE_EXISTED=false
[ -d "$WORKSPACE" ] && WORKSPACE_EXISTED=true
mkdir -p "$WORKSPACE/records"
if [ ! -e "$WORKSPACE/INDEX.md" ]; then
  cp "$SOURCE_ROOT/templates/workspace/INDEX.md" "$WORKSPACE/INDEX.md"
fi

if [ "$MODE" = 'update-workspace' ] || [ ! -f "$VERSION_FILE" ]; then
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

printf 'instancia de memoria lista: %s (workspace: %s)\n' "$MEM_DIR" "$(workspace_state)"
