#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
PYTHON_BIN=${PYTHON_BIN:-python3}
command -v "$PYTHON_BIN" >/dev/null 2>&1 || { printf '%s\n' "python no disponible: $PYTHON_BIN" >&2; exit 2; }

TEMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TEMP_ROOT"' EXIT
VENV="$TEMP_ROOT/venv"
"$PYTHON_BIN" -m venv "$VENV"
VENV_PYTHON="$VENV/bin/python"
VENV_ATO_MEM="$VENV/bin/ato-mem"

before=$(git -C "$ROOT" status --porcelain -- vault)
"$VENV_PYTHON" -m pip install .
"$VENV_ATO_MEM" --help >/dev/null
"$VENV_PYTHON" -m ato_ai_mem --help >/dev/null
result=$("$VENV_ATO_MEM" retrieve --vault "$ROOT/vault" --query 'vault fuente' --format json)
printf '%s\n' "$result" | "$VENV_PYTHON" -c 'import json, sys; payload = json.load(sys.stdin); assert payload["command"] == "retrieve"; assert payload["items"]'
after=$(git -C "$ROOT" status --porcelain -- vault)
[ "$before" = "$after" ] || { printf '%s\n' 'el smoke test modificó vault/' >&2; exit 1; }

printf '%s\n' 'smoke test de instalación y no mutación superado'
