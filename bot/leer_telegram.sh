#!/bin/ash
CONFIG_FILE="$HOME/bin/telegram.config"
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE" || { echo "Error: Missing $CONFIG_FILE"; exit 1; }
[ "$1" = "-c" ] && { CONFIG_FILE="$2"; shift 2; }
[ -z "$TG_URL" ] && { echo "Error: TG_URL undefined"; exit 1; }
[ -z "$TG_USER_ID" ] && { echo "Error: TG_USER_ID undefined"; exit 1; }
[ -z "$TG_CHAT_ID" ] && { echo "Error: TG_CHAT_ID undefined"; exit 1; }

LAST_UPDATE_ID_FILE="$HOME/bin/last_update_id.txt"
MAX_COMMAND_LENGTH=100
ALLOWED_COMMANDS="ls echo pwd"

LAST_UPDATE_ID=$([ -f "$LAST_UPDATE_ID_FILE" ] && cat "$LAST_UPDATE_ID_FILE" || echo 0)

RESPONSE=$(curl -s "$TG_URL/getUpdates?offset=$((LAST_UPDATE_ID + 1))")
[ "$(echo "$RESPONSE" | jq '.result | length')" -eq 0 ] && exit 0

echo "$RESPONSE" | jq -c '.result[]' | while IFS= read -r UPDATE; do
    UPDATE_ID=$(echo "$UPDATE" | jq '.update_id')
    MESSAGE=$(echo "$UPDATE" | jq -r '.message.text // empty')
    USER_ID=$(echo "$UPDATE" | jq -r '.message.from.id // empty')

    [ "$USER_ID" != "$TG_USER_ID" ] && continue
    [ -z "$MESSAGE" ] || [ "$(echo "$MESSAGE" | wc -c)" -gt "$MAX_COMMAND_LENGTH" ] && continue

    COMMAND=$(echo "$MESSAGE" | awk '{print $1}')
    if echo "$ALLOWED_COMMANDS" | grep -qw "$COMMAND"; then
        OUTPUT=$( (COLUMNS=1000; eval "$MESSAGE" 2>&1) | head -c 4000 )
    else
        OUTPUT="❌❌ no permitido ❌❌"
    fi

    [ -n "$OUTPUT" ] && curl -s -X POST "$TG_URL/sendMessage" \
        -d "chat_id=$TG_CHAT_ID" \
        -d "text=📌 Comando: <code>${MESSAGE}</code>%0A%0A${OUTPUT}" \
        -d "parse_mode=HTML"

    echo "$UPDATE_ID" > "$LAST_UPDATE_ID_FILE"
done
