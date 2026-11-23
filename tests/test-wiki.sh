#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT
INSTALL=$TEMP_ROOT/installed-skill
mkdir -p "$INSTALL"
cp "$ROOT/SKILL.md" "$ROOT/VERSION" "$ROOT/WIKI_FORMAT" "$INSTALL/"
cp -R "$ROOT/scripts" "$ROOT/templates" "$ROOT/wiki" "$INSTALL/"

check_output=$("$ROOT/scripts/wiki.sh" check)
printf '%s\n' "$check_output" | grep -F 'wiki.state: valid' >/dev/null
check_output=$(cd "$TEMP_ROOT" && "$INSTALL/scripts/wiki.sh" check)
printf '%s\n' "$check_output" | grep -F 'wiki.state: valid' >/dev/null

if "$INSTALL/scripts/wiki.sh" check --target "$TEMP_ROOT" >/dev/null 2>&1; then exit 1; fi
if "$INSTALL/scripts/wiki.sh" check --source >/dev/null 2>&1; then exit 1; fi

(cd "$INSTALL" && ./scripts/wiki.sh create-domain --id isolated --title 'Isolated Skill')
[ -f "$INSTALL/wiki/20_domains/isolated/domain.yml" ]
[ ! -e "$ROOT/wiki/20_domains/isolated" ]
(cd "$INSTALL" && ./scripts/wiki.sh check)

(cd "$INSTALL" && ./scripts/wiki.sh init-layout)
[ ! -e "$INSTALL/wiki/99_runtime" ]

CR=$(printf '\r')
if (cd "$INSTALL" && ./scripts/wiki.sh create-domain --id invalid-cr --title "Invalid${CR}Title" >/dev/null 2>&1); then exit 1; fi
[ ! -e "$INSTALL/wiki/20_domains/invalid-cr" ]
rm -f "$INSTALL/wiki/.local-mem.lock"
LF='
'
if (cd "$INSTALL" && ./scripts/wiki.sh create-domain --id invalid-lf --title "Invalid${LF}Title" >/dev/null 2>&1); then exit 1; fi
[ ! -e "$INSTALL/wiki/20_domains/invalid-lf" ]
rm -f "$INSTALL/wiki/.local-mem.lock"

OUTSIDE=$TEMP_ROOT/outside-domains
mkdir -p "$OUTSIDE"
mv "$INSTALL/wiki/20_domains" "$INSTALL/wiki/20_domains.local"
ln -s "$OUTSIDE" "$INSTALL/wiki/20_domains"
if (cd "$INSTALL" && ./scripts/wiki.sh check >/dev/null 2>&1); then exit 1; fi
if (cd "$INSTALL" && ./scripts/wiki.sh create-domain --id escaped >/dev/null 2>&1); then exit 1; fi
[ ! -e "$OUTSIDE/escaped" ]
rm "$INSTALL/wiki/20_domains"
mv "$INSTALL/wiki/20_domains.local" "$INSTALL/wiki/20_domains"

OUTSIDE_FILE=$TEMP_ROOT/outside.md
printf '%s\n' '# Fuera de la wiki' > "$OUTSIDE_FILE"
ln -s "$OUTSIDE_FILE" "$INSTALL/wiki/20_domains/isolated/records/external.md"
if (cd "$INSTALL" && ./scripts/wiki.sh check >/dev/null 2>&1); then exit 1; fi
rm "$INSTALL/wiki/20_domains/isolated/records/external.md"
 (cd "$INSTALL" && ./scripts/wiki.sh check)

cp "$INSTALL/WIKI_FORMAT" "$TEMP_ROOT/WIKI_FORMAT.saved"
printf '%s\n' 99 > "$INSTALL/WIKI_FORMAT"
if "$INSTALL/scripts/wiki.sh" check >/dev/null 2>&1; then exit 1; fi
mv "$TEMP_ROOT/WIKI_FORMAT.saved" "$INSTALL/WIKI_FORMAT"
(cd "$INSTALL" && ./scripts/wiki.sh check)

printf '%s\n' 'pruebas de wiki raíz única superadas'
