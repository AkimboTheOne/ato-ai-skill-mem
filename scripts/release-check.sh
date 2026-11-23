#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
FORMAT=text
while [ "$#" -gt 0 ]; do
  case "$1" in
    --format)
      [ "$#" -ge 2 ] || { printf '%s\n' 'error: --format requiere un valor' >&2; exit 2; }
      FORMAT=$2; shift 2 ;;
    --help|-h)
      printf '%s\n' 'Uso: scripts/release-check.sh [--format text|json]'
      exit 0 ;;
    *) printf '%s\n' "error: argumento desconocido: $1" >&2; exit 2 ;;
  esac
done
[ "$FORMAT" = text ] || [ "$FORMAT" = json ] || { printf '%s\n' 'error: --format debe ser text o json' >&2; exit 2; }

VERSION=$(tr -d '[:space:]' < "$ROOT/VERSION")
WIKI_FORMAT=$(tr -d '[:space:]' < "$ROOT/WIKI_FORMAT")
TAG=v$VERSION
BRANCH=$(git -C "$ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || printf unavailable)
HEAD=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || printf unavailable)
TAG_HEAD=$(git -C "$ROOT" rev-list -n 1 "$TAG" 2>/dev/null || printf unavailable)
MAIN=$(git -C "$ROOT" rev-parse main 2>/dev/null || printf unavailable)
ORIGIN_MAIN=$(git -C "$ROOT" rev-parse refs/remotes/origin/main 2>/dev/null || printf unavailable)
DIRTY=$(git -C "$ROOT" status --porcelain 2>/dev/null || printf unknown)

check_version=fail
check_format=fail
check_branch=fail
check_worktree=fail
check_tag=fail
check_head_tag=fail
check_sync=fail
check_wiki=fail
blockers=''
add_blocker() { if [ -n "$blockers" ]; then blockers="$blockers,$1"; else blockers=$1; fi; }
printf '%s\n' "$VERSION" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' >/dev/null && check_version=pass || add_blocker version
printf '%s\n' "$WIKI_FORMAT" | grep -E '^[1-9][0-9]*$' >/dev/null && check_format=pass || add_blocker wiki_format
[ "$BRANCH" = main ] && check_branch=pass || add_blocker branch
[ -z "$DIRTY" ] && check_worktree=pass || add_blocker worktree
[ "$TAG_HEAD" != unavailable ] && check_tag=pass || add_blocker tag
[ "$HEAD" != unavailable ] && [ "$HEAD" = "$TAG_HEAD" ] && check_head_tag=pass || add_blocker head_tag
[ "$MAIN" != unavailable ] && [ "$MAIN" = "$ORIGIN_MAIN" ] && check_sync=pass || add_blocker main_sync
if "$ROOT/scripts/wiki.sh" check >/dev/null 2>&1; then check_wiki=pass; else add_blocker wiki; fi

if [ -n "$blockers" ]; then READY=false; EXIT_CODE=1; else READY=true; EXIT_CODE=0; fi
if [ "$FORMAT" = json ]; then
  printf '{"schema":1,"ready":%s,"version":"%s","expected_tag":"%s","checks":{"version":"%s","wiki_format":"%s","branch":"%s","worktree":"%s","tag":"%s","head_tag":"%s","main_sync":"%s","wiki":"%s"},"blockers":[' "$READY" "$VERSION" "$TAG" "$check_version" "$check_format" "$check_branch" "$check_worktree" "$check_tag" "$check_head_tag" "$check_sync" "$check_wiki"
  old_ifs=$IFS; IFS=,
  first=true
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
  printf 'release.expected_tag: %s\n' "$TAG"
  printf 'release.check.version: %s\n' "$check_version"
  printf 'release.check.wiki_format: %s\n' "$check_format"
  printf 'release.check.branch: %s (%s)\n' "$check_branch" "$BRANCH"
  printf 'release.check.worktree: %s\n' "$check_worktree"
  printf 'release.check.tag: %s\n' "$check_tag"
  printf 'release.check.head_tag: %s\n' "$check_head_tag"
  printf 'release.check.main_sync: %s\n' "$check_sync"
  printf 'release.check.wiki: %s\n' "$check_wiki"
  printf 'release.blockers: %s\n' "${blockers:-none}"
fi
exit "$EXIT_CODE"
