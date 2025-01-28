#!/bin/bash

# Usar el token para telegram
CONFIG_FILE="bot.config"

# Cargar configuración
[ -f $CONFIG_FILE ] && . $CONFIG_FILE || { echo "Error: Archivo $CONFIG_FILE no encontrado."; exit 1; }
[ -z "$tg_url" ] && { echo "Error: tg_url no definido."; exit 1; }

# Verifica que la variable TELEGRAM_BOT_TOKEN esté definida
if [ -z "$tg_url" ]; then
    echo "Error: tg_url no está definido en '$CONFIG_FILE'."
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
MESSAGE=$(printf "Servidor %s:
Uptime: %s
Uso de Disco: %s
Uso de Memoria: %s
Temperatura CPU: %s°C
Tailscale IPv4: %s" "$HOSTNAME" "$UPTIME" "$DISK_USAGE" "$MEMORY" "$TEMP_C" "$TAILSCALE_IP")


# Enviar mensaje a través del bot de Telegram
# 
CHAT_ID="5098223"

curl -s -X POST $tg_url -d chat_id=$CHAT_ID -d text="$MESSAGE" --header "Content-Type: application/x-www-form-urlencoded"
