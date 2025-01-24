#!/bin/sh

# Cargar configuración
[ -f "bot.config" ] && . "bot.config" || { echo "Error: Archivo 'bot.config' no encontrado."; exit 1; }
[ -z "$TELEGRAM_BOT_TOKEN" ] && { echo "Error: TELEGRAM_BOT_TOKEN no definido."; exit 1; }

# Validar argumentos
[ "$#" -lt 2 ] && { echo "Uso: $0 [CHAT_ID] [WEBSITE_URL...]"; exit 1; }

CHAT_ID="$1"; shift

# Procesar sitios web
for URL in "$@"; do
    FILE=$(echo "$URL" | awk -F/ '{print $3 "_" $4}' | tr -cd '[:alnum:]_').txt
    TEXT=$(curl -s "$URL" | awk '{
        # Eliminar etiquetas HTML
        gsub(/<[^>]*>/, "");
        # Reemplazar entidades HTML
        gsub(/&[a-zA-Z0-9]*;/, " ");
        # Concatenar líneas y eliminar espacios al inicio y al final
        for (i = 1; i <= NF; i++) {
            if ($i != "") {
                printf "%s ", $i;  # Imprimir palabras no vacías
            }
        }
    }' | awk '{$1=$1};1')  # Eliminar espacios en blanco al inicio y al final

    [ $? -ne 0 ] && { echo "Error al obtener $URL"; continue; }
    [ -f "$FILE" ] && OLD_TEXT=$(cat "$FILE") || OLD_TEXT=""

    if [ "$TEXT" != "$OLD_TEXT" ]; then
        MSG="$URL ha cambiado"
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d "chat_id=$CHAT_ID" -d "text=$MSG" | grep -q '"ok":true' && \
            echo "Mensaje enviado para $URL" || \
            echo "Error al enviar mensaje para $URL"
        echo "$TEXT" > "$FILE"
    else
        echo "No cambios en $URL"
    fi
done
