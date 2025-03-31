#!/bin/sh

# Validar argumentos
[ "$#" -lt 1 ] && { echo "Uso: $0 [WEBSITE_URL...]"; exit 1; }

# Procesar sitios web
for URL in "$@"; do
    FILE=$(echo "$URL" | awk '{gsub(/https?:\/\//, ""); gsub(/www\./, ""); gsub(/\//, "_"); gsub(/\./, "_"); print $0 ".txt"}')

    # Obtener el contenido de la URL
    TEXT=$(curl -s $curl_args "$URL" | awk '
        # Extraer el contenido entre las etiquetas <body> y </body>
        /<body[^>]*>/,/<\/body>/ {
            if ($0 ~ /<\/body>/) {
                # Si encontramos </body>, imprimimos hasta ahí y salimos
                print substr($0, 1, index($0, "</body>") - 1);
                exit;
            }
            print;
        }
    ' | awk '
        # Eliminar etiquetas HTML
        gsub(/<[^>]*>/, "");
        # Reemplazar entidades HTML
        gsub(/&[a-zA-Z0-9]+;/, " ");
        # Eliminar espacios al inicio y al final
        gsub("^%s*(.-)%s*$", "%1");
        # Eliminar espacios múltiples
        gsub("%s+", " ");
        # Imprimir el resultado final
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
