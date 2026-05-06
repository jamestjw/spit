#!/usr/bin/env bash
#
# spit - End-to-end encrypted paste upload
#
# Encrypts stdin with AES-256-CBC and uploads to your Spit server.
# The encryption key is never sent to the server — it's appended to
# the URL as a fragment (#key=...), which browsers never transmit.
#
# Usage:
#   echo "secret" | spit
#   cat file.txt | spit
#   spit < file.txt
#

set -euo pipefail

SPIT_URL="${SPIT_URL:-{{SPIT_URL}}}"

# Generate random key (32 bytes for AES-256) and IV (16 bytes for CBC)
KEY_HEX=$(openssl rand -hex 32)
IV_HEX=$(openssl rand -hex 16)

# Encrypt stdin to a temp file so we can upload once
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

openssl enc -aes-256-cbc -K "$KEY_HEX" -iv "$IV_HEX" -nosalt < /dev/stdin | base64 -w 0 > "$TMPFILE"

# Upload via PUT /
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X PUT \
  -H "Content-Type: text/plain" \
  -d @"$TMPFILE" \
  "${SPIT_URL}/?encrypted=true")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "201" ]; then
  printf "  Error: upload failed (HTTP %s)\n" "$HTTP_CODE" >&2
  printf "  %s\n" "$BODY" >&2
  exit 1
fi

SLUG=$(echo "$BODY" | grep -oE '[a-zA-Z0-9_-]{6,32}$' | head -1)

if [ -z "$SLUG" ]; then
  printf "  Error: could not parse response: %s\n" "$BODY" >&2
  exit 1
fi

BASE_URL="${SPIT_URL}/p/${SLUG}"
FRAGMENT="#key=${KEY_HEX}:${IV_HEX}"

printf '\n'
printf '  Encrypted paste uploaded\n'
printf '  Share this URL (key is in the fragment, never sent to server):\n\n'
printf '  \033[1;38;5;208m%s%s\033[0m\n\n' "$BASE_URL" "$FRAGMENT"
printf '  To decrypt locally:\n'
printf '  curl -s %s/raw/%s | base64 -d | openssl enc -d -aes-256-cbc -K %s -iv %s\n\n' \
  "$SPIT_URL" "$SLUG" "$KEY_HEX" "$IV_HEX"
