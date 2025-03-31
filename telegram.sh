#!/bin/sh

CONFIG_FILE="$HOME/bin/telegram.config"
[ -f $CONFIG_FILE ] && . $CONFIG_FILE || { echo "Error: Archivo $CONFIG_FILE no encontrado."; exit 1; }
#[ -f "telegram.config" ] && . "telegram.config" || { echo "Error: Archivo 'telegram.config' no encontrado."; exit 1; }
[ -z "$TG_URL" ] && { echo "Error: TG_URL no definido."; exit 1; }
[ -z "$CHAT_ID" ] && { echo "Error: CHAT_ID no definido."; exit 1; }

# Uso: $0 MENSAJE
[ "$#" -lt 1 ] && { echo "Uso: $0 MENSAJE"; exit 1; }

if [ "$#" -gt 0 ]; then
  MESSAGE="$1"
else
  MESSAGE=$(cat -)
fi

curl -s -X POST "$TG_URL" \
  -d "chat_id=$CHAT_ID" \
  --data-urlencode "text=$MESSAGE" \
  --header "Content-Type: application/x-www-form-urlencoded"
