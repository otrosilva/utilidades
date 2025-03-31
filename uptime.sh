UPTIME=$(uptime | sed -E 's/^[^,]*up *//; s/, *[[:digit:]]* users.*//; s/min/minutes/; s/([[:digit:]]+):0?([[:digit:]]+)/\1 hours, \2 minutes/')
TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
if [ -n "$TEMP" ]; then
  TEMP_C="$((TEMP / 1000))"
else
  TEMP_C=""
fi
MEMORY=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
TAILSCALE_IP=$(tailscale ip --4 2>/dev/null)
if [ -z "$TAILSCALE_IP" ]; then
  TAILSCALE_IP="no está disponible"
fi

if [[ "$TEMP_C" != "" && "$TEMP_C" -gt 70 ]]; then
  TEMP_MESSAGE="hace mucho calor $TEMP_C"
else
  TEMP_MESSAGE="la temperatura es de $TEMP_C °C"
fi

/home/jose/bin/random_phrases.sh

HOSTNAME=$('hostname')

echo "+----------------------"
echo "¡$HOSTNAME ha estado en guardia durante $UPTIME!.
Inventario en uso: $MEMORY, $TEMP_MESSAGE.
Nuestro portal $TAILSCALE_IP.
Tu diario es bit tareas."
echo "+----------------------"
