#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT
INSTALL=$TEMP_ROOT/installed-skill
mkdir -p "$INSTALL"
cp "$ROOT/SKILL.md" "$ROOT/VERSION" "$ROOT/VAULT_FORMAT" "$INSTALL/"
cp -R "$ROOT/scripts" "$ROOT/templates" "$ROOT/vault" "$INSTALL/"

check_output=$("$ROOT/scripts/vault.sh" check)
printf '%s\n' "$check_output" | grep -F 'vault.state: valid' >/dev/null
check_output=$(cd "$TEMP_ROOT" && "$INSTALL/scripts/vault.sh" check)
printf '%s\n' "$check_output" | grep -F 'vault.state: valid' >/dev/null

if "$INSTALL/scripts/vault.sh" check --target "$TEMP_ROOT" >/dev/null 2>&1; then exit 1; fi
if "$INSTALL/scripts/vault.sh" check --source >/dev/null 2>&1; then exit 1; fi

(cd "$INSTALL" && ./scripts/vault.sh create-domain --id isolated --title 'Isolated Skill')
[ -f "$INSTALL/vault/20_domains/isolated/domain.yml" ]
[ ! -e "$ROOT/vault/20_domains/isolated" ]
(cd "$INSTALL" && ./scripts/vault.sh check)

(cd "$INSTALL" && ./scripts/vault.sh init-layout)
[ ! -e "$INSTALL/vault/99_runtime" ]
cp "$INSTALL/VAULT_FORMAT" "$TEMP_ROOT/VAULT_FORMAT.saved"
printf '%s\n' 99 > "$INSTALL/VAULT_FORMAT"
if "$INSTALL/scripts/vault.sh" check >/dev/null 2>&1; then exit 1; fi
mv "$TEMP_ROOT/VAULT_FORMAT.saved" "$INSTALL/VAULT_FORMAT"
(cd "$INSTALL" && ./scripts/vault.sh check)

printf '%s\n' 'pruebas de vault raíz única superadas'
