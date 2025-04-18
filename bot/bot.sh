#!/bin/sh

[ "$#" -lt 1 ] && { echo "Uso: $0 [WEBSITE_URL...]"; exit 1; }

for URL in "$@"; do
    FILE=$(echo "$URL" | awk '{gsub(/https?:\/\//, ""); gsub(/www\./, ""); gsub(/\//, "_"); gsub(/\./, "_"); print $0 ".txt"}')

    TEXT=$(curl -s $curl_args "$URL" | awk '
        /<body[^>]*>/,/<\/body>/ {
            if ($0 ~ /<\/body>/) {
                print substr($0, 1, index($0, "</body>") - 1);
                exit;
            }
            print;
        }
    ' | awk '
        gsub(/<[^>]*>/, "");
        gsub(/&[a-zA-Z0-9]+;/, " ");
        gsub("^%s*(.-)%s*$", "%1");
        gsub("%s+", " ");
        1
    ')

    [ $? -ne 0 ] && { echo "Error al obtener $URL"; continue; }
    [ -f "$FILE" ] && OLD_TEXT=$(cat "$FILE") || OLD_TEXT=""

    if [ "$TEXT" != "$OLD_TEXT" ]; then
        ./telegram.sh "$URL ha cambiado" \
            | grep -q '"ok":true' && \
            echo "$URL mensaje enviado" || \
            echo "[$(date +"$format_date")] $URL error al enviar mensaje." >> bot.log
        echo "$TEXT" > "$FILE"
        echo "[$(date +"$format_date")] $URL ha cambiado." >> bot.log
    else
        echo "$URL sin cambios."
    fi
done
