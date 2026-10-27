#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
FORMAT=text
POST_RELEASE=false

usage() {
  cat <<'EOF'
Uso: scripts/release-check.sh [--format text|json] [--post-release]

Ejecuta comprobaciones read-only del gate de release de la fuente.
No crea tags, commits, pushes ni modifica la vault.

Opciones:
  --format text|json  Formato de salida (por defecto: text).
  --post-release      Comprueba también el manifiesto fuente posterior al tag.
EOF
}

fail_usage() {
  printf '%s\n' "error: $*" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --format)
      [ "$#" -ge 2 ] || fail_usage '--format requiere un valor'
      FORMAT=$2
      shift 2
      ;;
    --post-release)
      POST_RELEASE=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail_usage "argumento desconocido: $1"
      ;;
  esac
done

case "$FORMAT" in
  text|json) ;;
  *) fail_usage '--format debe ser text o json' ;;
esac

VERSION=$(tr -d '[:space:]' < "$ROOT/VERSION")
VAULT_FORMAT=$(tr -d '[:space:]' < "$ROOT/VAULT_FORMAT")
EXPECTED_TAG="v$VERSION"
BRANCH=$(git -C "$ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'detached-or-unavailable')
HEAD_REVISION=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || printf 'unavailable')
MASTER_REVISION=$(git -C "$ROOT" rev-parse master 2>/dev/null || printf 'unavailable')
TAG_REVISION=$(git -C "$ROOT" rev-list -n 1 "$EXPECTED_TAG" 2>/dev/null || printf 'unavailable')
ORIGIN_MASTER_REVISION=$(git -C "$ROOT" rev-parse refs/remotes/origin/master 2>/dev/null || printf 'unavailable')
DIRTY=$(git -C "$ROOT" status --porcelain 2>/dev/null || printf 'unknown')

check_version=fail
check_vault_format=fail
check_branch=fail
check_clean=fail
check_tag=fail
check_head_tag=fail
check_origin_master=fail
check_vault=fail
check_manifest=skip
blockers=''

add_blocker() {
  if [ -n "$blockers" ]; then blockers="$blockers,$1"; else blockers=$1; fi
}

if printf '%s\n' "$VERSION" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' >/dev/null; then check_version=pass; else add_blocker version; fi
if printf '%s\n' "$VAULT_FORMAT" | grep -E '^[1-9][0-9]*$' >/dev/null; then check_vault_format=pass; else add_blocker vault_format; fi
if [ "$BRANCH" = master ]; then check_branch=pass; else add_blocker branch; fi
if [ -z "$DIRTY" ]; then
  check_clean=pass
elif [ "$POST_RELEASE" = true ] && [ "$(git -C "$ROOT" diff --name-only)" = 'vault/.ato-ai-skill-mem-version.yml' ] && [ -z "$(git -C "$ROOT" ls-files --others --exclude-standard)" ]; then
  check_clean=pass
else
  add_blocker worktree
fi
if [ "$TAG_REVISION" != unavailable ]; then check_tag=pass; else add_blocker tag; fi
if [ "$HEAD_REVISION" != unavailable ] && [ "$HEAD_REVISION" = "$TAG_REVISION" ]; then check_head_tag=pass; else add_blocker head_tag; fi
if [ "$MASTER_REVISION" != unavailable ] && [ "$ORIGIN_MASTER_REVISION" != unavailable ] && [ "$MASTER_REVISION" = "$ORIGIN_MASTER_REVISION" ]; then check_origin_master=pass; else add_blocker origin_master; fi
if "$ROOT/scripts/vault.sh" check --source >/dev/null 2>&1; then check_vault=pass; else add_blocker vault; fi

if [ "$POST_RELEASE" = true ]; then
  MARKER="$ROOT/vault/.ato-ai-skill-mem-version.yml"
  marker_value() {
    sed -n "s/^$1: *//p" "$MARKER" | sed -n '1p' | tr -d '"'
  }
  if [ -f "$MARKER" ] && [ "$(marker_value vault_kind)" = source ] && [ "$(marker_value skill_version)" = "$VERSION" ] && [ "$(marker_value vault_format)" = "$VAULT_FORMAT" ] && [ "$(marker_value source_revision)" = "$TAG_REVISION" ] && [ "$(marker_value source_tag)" = "$EXPECTED_TAG" ]; then
    check_manifest=pass
  else
    check_manifest=fail
    add_blocker manifest
  fi
fi

if [ -n "$blockers" ]; then READY=false; EXIT_CODE=1; else READY=true; EXIT_CODE=0; fi

if [ "$FORMAT" = json ]; then
  printf '{"schema":1,"ready":%s,"version":"%s","expected_tag":"%s","post_release":%s,"checks":{"version":"%s","vault_format":"%s","branch":"%s","worktree":"%s","tag":"%s","head_tag":"%s","origin_master":"%s","vault":"%s","manifest":"%s"},"blockers":[' "$READY" "$VERSION" "$EXPECTED_TAG" "$POST_RELEASE" "$check_version" "$check_vault_format" "$check_branch" "$check_clean" "$check_tag" "$check_head_tag" "$check_origin_master" "$check_vault" "$check_manifest"
  first=true
  old_ifs=$IFS
  IFS=','
  for blocker in $blockers; do
    [ -n "$blocker" ] || continue
    [ "$first" = true ] || printf ','
    printf '"%s"' "$blocker"
    first=false
  done
  IFS=$old_ifs
  printf ']}\n'
else
  printf 'release.ready: %s\n' "$READY"
  printf 'release.version: %s\n' "$VERSION"
  printf 'release.expected_tag: %s\n' "$EXPECTED_TAG"
  printf 'release.check.version: %s\n' "$check_version"
  printf 'release.check.vault_format: %s\n' "$check_vault_format"
  printf 'release.check.branch: %s (%s)\n' "$check_branch" "$BRANCH"
  printf 'release.check.worktree: %s\n' "$check_clean"
  printf 'release.check.tag: %s\n' "$check_tag"
  printf 'release.check.head_tag: %s\n' "$check_head_tag"
  printf 'release.check.origin_master: %s\n' "$check_origin_master"
  printf 'release.check.vault: %s\n' "$check_vault"
  printf 'release.check.manifest: %s\n' "$check_manifest"
  printf 'release.blockers: %s\n' "${blockers:-none}"
fi

exit "$EXIT_CODE"
