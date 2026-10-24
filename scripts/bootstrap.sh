#!/bin/sh

set -eu

TARGET=''
MODE='bootstrap'

usage() {
  cat <<'EOF'
Uso: bootstrap.sh --target RUTA_DEL_PROYECTO

Crea o valida una instancia híbrida de ato-ai-skill-mem en RUTA_DEL_PROYECTO/mem.
Este comando nunca modifica RUTA_DEL_PROYECTO/AGENTS.md.

Opciones:
  --status              Informa la alineación entre el release fuente y el workspace.
  --update-workspace    Actualiza solo workspace/.ato-ai-skill-mem-version.yml.
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
      MODE='status'
      shift
      ;;
    --update-workspace)
      MODE='update-workspace'
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

[ -n "$TARGET" ] || fail '--target es obligatorio'
[ -d "$TARGET" ] || fail "el destino no es un directorio: $TARGET"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
SOURCE_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
TARGET_ROOT=$(CDPATH= cd -- "$TARGET" && pwd -P)
MEM_DIR=$TARGET_ROOT/mem

[ -f "$SOURCE_ROOT/SKILL.md" ] || fail "falta el SKILL.md canónico en $SOURCE_ROOT"
[ -f "$SOURCE_ROOT/VERSION" ] || fail "falta el VERSION canónico en $SOURCE_ROOT"
[ -f "$SOURCE_ROOT/WORKSPACE_FORMAT" ] || fail "falta el WORKSPACE_FORMAT canónico en $SOURCE_ROOT"
[ -d "$SOURCE_ROOT/references" ] || fail "faltan las references canónicas en $SOURCE_ROOT"
[ -d "$SOURCE_ROOT/templates" ] || fail "faltan las templates canónicas en $SOURCE_ROOT"

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
SOURCE_TAG='unreleased'
SOURCE_STATE='not-release-aligned'
if [ "$SOURCE_BRANCH" = 'master' ] && [ "$SOURCE_REVISION" = "$MASTER_REVISION" ] && [ "$SOURCE_REVISION" = "$TAG_REVISION" ] && [ -z "$SOURCE_DIRTY" ]; then
  SOURCE_TAG=$EXPECTED_TAG
  SOURCE_STATE='release-aligned'
fi

WORKSPACE=$MEM_DIR/workspace
VERSION_FILE=$WORKSPACE/.ato-ai-skill-mem-version.yml

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
  elif [ "$(workspace_data_compatibility)" != 'compatible' ]; then
    printf '%s\n' 'migration-required'
  elif [ "$(read_marker skill_version)" != "$SKILL_VERSION" ]; then
    case "$(version_relation "$(read_marker skill_version)")" in
      source-newer) printf '%s\n' 'compatible-update-available' ;;
      workspace-newer) printf '%s\n' 'workspace-newer' ;;
      *) printf '%s\n' 'version-mismatch' ;;
    esac
  elif [ "$(read_marker source_revision)" != "$SOURCE_REVISION" ]; then
    printf '%s\n' 'source-revision-differs'
  else
    printf '%s\n' 'aligned'
  fi
}

write_marker() {
  marker_created_at=$1
  marker_date=$(date -u +%Y-%m-%d)
  sed \
    -e "s/^skill_version: .*/skill_version: $SKILL_VERSION/" \
    -e "s/^workspace_format: .*/workspace_format: $CURRENT_WORKSPACE_FORMAT/" \
    -e "s/^source_revision: .*/source_revision: $SOURCE_REVISION/" \
    -e "s/^source_tag: .*/source_tag: $SOURCE_TAG/" \
    -e "s/^created_at: .*/created_at: $marker_created_at/" \
    -e "s/^updated_at: .*/updated_at: $marker_date/" \
    "$SOURCE_ROOT/templates/workspace/SKILL-VERSION.yml" > "$VERSION_FILE"
}

if [ "$MODE" = 'status' ]; then
  printf 'source.version: %s\n' "$SKILL_VERSION"
  printf 'source.expected_tag: %s\n' "$EXPECTED_TAG"
  printf 'source.branch: %s\n' "$SOURCE_BRANCH"
  printf 'source.revision: %s\n' "$SOURCE_REVISION"
  printf 'source.state: %s\n' "$SOURCE_STATE"
  printf 'workspace.format: %s\n' "$(marker_workspace_format)"
  printf 'workspace.expected_format: %s\n' "$CURRENT_WORKSPACE_FORMAT"
  printf 'workspace.data_compatibility: %s\n' "$(workspace_data_compatibility)"
  printf 'workspace.state: %s\n' "$(workspace_state)"
  if [ -f "$VERSION_FILE" ]; then
    printf 'workspace.skill_version: %s\n' "$(read_marker skill_version)"
    printf 'workspace.source_revision: %s\n' "$(read_marker source_revision)"
    printf 'workspace.created_at: %s\n' "$(read_marker created_at)"
    printf 'workspace.updated_at: %s\n' "$(read_marker updated_at)"
  fi
  exit 0
fi

if [ -e "$MEM_DIR" ] && [ ! -d "$MEM_DIR" ]; then
  fail "la ruta de instancia existe pero no es un directorio: $MEM_DIR"
fi
if [ -L "$MEM_DIR" ]; then
  fail "el directorio de instancia debe ser local, no un enlace simbólico: $MEM_DIR"
fi

if [ "$MODE" = 'update-workspace' ] && [ "$SOURCE_STATE" != 'release-aligned' ]; then
  fail "la actualización del workspace requiere una fuente release-aligned"
fi
if [ "$MODE" = 'update-workspace' ] && [ -d "$WORKSPACE" ] && [ "$(workspace_data_compatibility)" != 'compatible' ]; then
  fail "el formato del workspace requiere una migración confirmada"
fi
if [ "$MODE" = 'update-workspace' ]; then
  case "$(workspace_state)" in
    absent|legacy-compatible|compatible-update-available|aligned) ;;
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

validate_link_destination "$SOURCE_ROOT/SKILL.md" "$MEM_DIR/SKILL.md"
validate_link_destination "$SOURCE_ROOT/references" "$MEM_DIR/references"
validate_link_destination "$SOURCE_ROOT/templates" "$MEM_DIR/templates"

mkdir -p "$MEM_DIR"
ensure_link "$SOURCE_ROOT/SKILL.md" "$MEM_DIR/SKILL.md"
ensure_link "$SOURCE_ROOT/references" "$MEM_DIR/references"
ensure_link "$SOURCE_ROOT/templates" "$MEM_DIR/templates"

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

printf 'instancia de memoria lista: %s (workspace: %s)\n' "$MEM_DIR" "$(workspace_state)"
