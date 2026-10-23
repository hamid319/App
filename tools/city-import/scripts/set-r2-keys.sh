#!/bin/bash
# Asks for the Cloudflare R2 API token values and writes them into .env.
# Input is hidden and never printed. Run from anywhere:
#   bash tools/city-import/scripts/set-r2-keys.sh
set -euo pipefail

ENV_FILE="$(cd "$(dirname "$0")/.." && pwd)/.env"
[ -f "$ENV_FILE" ] || cp "$(dirname "$ENV_FILE")/.env.example" "$ENV_FILE"
chmod 600 "$ENV_FILE"

ask() {
  local key="$1" prompt="$2" value
  read -r -s -p "$prompt: " value
  echo
  value="$(printf '%s' "$value" | tr -d '[:space:]')"
  if [ -z "$value" ]; then
    echo "  übersprungen (leer)"
    return
  fi
  # Replace the line KEY=... without echoing the value.
  KEY="$key" VALUE="$value" perl -0pi -e 's/^\Q$ENV{KEY}\E=.*$/$ENV{KEY}=$ENV{VALUE}/m' "$ENV_FILE"
  echo "  $key gespeichert (${#value} Zeichen)"
}

echo "Werte aus Cloudflare › R2 › API Token einfügen (Eingabe bleibt unsichtbar)."
ask R2_ACCOUNT_ID "Account ID"
ask R2_ACCESS_KEY_ID "Access Key ID"
ask R2_SECRET_ACCESS_KEY "Secret Access Key"
echo "Fertig: $ENV_FILE"
