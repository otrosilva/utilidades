#!/bin/bash

# Usar el token para telegram
CONFIG_FILE="bot.config"

if [ -f "$CONFIG_FILE" ]; then
    # Carga las variables del archivo
    . "$CONFIG_FILE"
else
    echo "Error: El archivo de configuración '$CONFIG_FILE' no existe."
    exit 1
fi

# Verifica que la variable TELEGRAM_BOT_TOKEN esté definida
if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo "Error: TELEGRAM_BOT_TOKEN no está definido en '$CONFIG_FILE'."
    exit 1
fi

# Obtener el uso del disco
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')

# Obtener información básica del sistema
HOSTNAME=$(hostname)

# Formatear el tiempo de actividad (uptime) para mostrar días, horas y minutos
UPTIME=$(uptime | sed -E 's/^[^,]*up *//; s/, *[[:digit:]]* users.*//; s/min/minutes/; s/([[:digit:]]+):0?([[:digit:]]+)/\1 hours, \2 minutes/')

# Obtener uso de memoria
MEMORY=$(free -h | awk '/Mem:/ {print $3 "/" $2}')

# Obtener temperatura de la CPU desde sysfs (si está disponible)
TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
if [ -n "$TEMP" ]; then
  TEMP_C=$((TEMP/1000))
else
  TEMP_C="No disponible"
fi

# Obtener la dirección IPv4 de Tailscale
TAILSCALE_IP=$(tailscale ip --4 2>/dev/null)
if [ -z "$TAILSCALE_IP" ]; then
  TAILSCALE_IP="No disponible"
fi

# Formatear el mensaje para Telegram
MESSAGE="Servidor $HOSTNAME:%0A%0A"
MESSAGE+="Uptime: $UPTIME%0A"
MESSAGE+="Uso de Disco: $DISK_USAGE%0A"
MESSAGE+="Uso de Memoria: $MEMORY%0A"
MESSAGE+="Temperatura CPU: $TEMP_C°C%0A"
MESSAGE+="Tailscale IPv4: $TAILSCALE_IP%0A"

# Enviar mensaje a través del bot de Telegram
# 
TELEGRAM_BOT_TOKEN="7065209211:AAF_GLMjPmyB7_81cO9vigPiw61fYmFgeR4"
CHAT_ID="5098223"
URL="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"

curl -s -X POST $URL -d chat_id=$CHAT_ID -d text="$MESSAGE" --header "Content-Type: application/x-www-form-urlencoded"

