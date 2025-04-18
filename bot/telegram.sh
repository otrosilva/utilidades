#!/bin/sh
MESSAGE=""
CONFIG_FILE="$HOME/bin/telegram.config"
[ "$1" = "-c" ] && { CONFIG_FILE="$2"; shift 2; }
[ "$#" -gt 0 ] && MESSAGE="$*" || { [ ! -t 0 ] && MESSAGE=$(cat) && [ -n "$MESSAGE" ] || { echo "Usage: $0 <Message>"; exit 1; }; }
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE" || { echo "Error: Archivo $CONFIG_FILE no encontrado."; exit 1; }
[ -z "$TG_URL" ] && { echo "Error: TG_URL no definido."; exit 1; }
[ -z "$TG_CHAT_ID" ] && { echo "Error: TG_CHAT_ID no definido."; exit 1; }
curl -s -X POST "$TG_URL/sendMessage" -d "chat_id=$TG_CHAT_ID" --data-urlencode "text=$MESSAGE" --header "Content-Type: application/x-www-form-urlencoded"
