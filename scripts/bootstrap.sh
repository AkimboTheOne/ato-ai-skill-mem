#!/bin/sh

set -eu

TARGET=''

usage() {
  cat <<'EOF'
Usage: bootstrap.sh --target PROJECT_PATH

Create or validate a hybrid ato-ai-skill-mem instance at PROJECT_PATH/mem.
This command never modifies PROJECT_PATH/AGENTS.md.
EOF
}

fail() {
  printf '%s\n' "error: $*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)
      [ "$#" -ge 2 ] || fail '--target requires a path'
      TARGET=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[ -n "$TARGET" ] || fail '--target is required'
[ -d "$TARGET" ] || fail "target is not a directory: $TARGET"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
SOURCE_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
TARGET_ROOT=$(CDPATH= cd -- "$TARGET" && pwd -P)
MEM_DIR=$TARGET_ROOT/mem

[ -f "$SOURCE_ROOT/SKILL.md" ] || fail "missing canonical SKILL.md in $SOURCE_ROOT"
[ -d "$SOURCE_ROOT/references" ] || fail "missing canonical references in $SOURCE_ROOT"
[ -d "$SOURCE_ROOT/templates" ] || fail "missing canonical templates in $SOURCE_ROOT"

if [ -e "$MEM_DIR" ] && [ ! -d "$MEM_DIR" ]; then
  fail "instance path exists but is not a directory: $MEM_DIR"
fi
if [ -L "$MEM_DIR" ]; then
  fail "instance directory must be local, not a symlink: $MEM_DIR"
fi

validate_link_destination() {
  source=$1
  destination=$2

  if [ -L "$destination" ]; then
    actual=$(readlink "$destination")
    [ "$actual" = "$source" ] || fail "existing link differs: $destination -> $actual"
    return
  fi

  if [ -e "$destination" ]; then
    fail "cannot replace existing non-link path: $destination"
  fi
}

ensure_link() {
  source=$1
  destination=$2

  if [ -L "$destination" ]; then
    return
  fi

  if ! ln -s "$source" "$destination"; then
    fail "could not create symlink $destination; enable symlink permissions instead of copying the skill"
  fi
}

validate_link_destination "$SOURCE_ROOT/SKILL.md" "$MEM_DIR/SKILL.md"
validate_link_destination "$SOURCE_ROOT/references" "$MEM_DIR/references"
validate_link_destination "$SOURCE_ROOT/templates" "$MEM_DIR/templates"

mkdir -p "$MEM_DIR"
ensure_link "$SOURCE_ROOT/SKILL.md" "$MEM_DIR/SKILL.md"
ensure_link "$SOURCE_ROOT/references" "$MEM_DIR/references"
ensure_link "$SOURCE_ROOT/templates" "$MEM_DIR/templates"

WORKSPACE=$MEM_DIR/workspace
mkdir -p "$WORKSPACE/records"
if [ ! -e "$WORKSPACE/INDEX.md" ]; then
  cp "$SOURCE_ROOT/templates/workspace/INDEX.md" "$WORKSPACE/INDEX.md"
fi

printf 'memory instance ready: %s\n' "$MEM_DIR"
