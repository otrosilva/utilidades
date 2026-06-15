#!/bin/sh
DRY_RUN=0
SERVER=""
# 1. Validar argumentos y buscar la bandera --dry o --dry-run
for arg in "$@"; do
    case "$arg" in
        --dry|--dry-run) DRY_RUN=1 ;;
        -*) echo "Opción no válida: $arg"; exit 1 ;;
        *)  [ -z "$SERVER" ] && SERVER="$arg" ;;
    esac
done
if [ -z "$SERVER" ]; then
    echo "Uso: $0 <SERVIDOR> [--dry]"
    exit 1
fi
DATE=$(date +"%Y-%m-%d")
# 2. Modo Simulacro (--dry)
if [ $DRY_RUN -eq 1 ]; then
    echo "=== MODO SIMULACRO (DRY RUN) ==="
    REMOTE_INFO=$(ssh -n "$SERVER" '
        [ ! -f ~/to_backup.txt ] && echo "$HOME" > ~/to_backup.txt
        [ ! -f ~/to_exclude.txt ] && echo ".cache/" > ~/to_exclude.txt
        echo "HOSTNAME:$(uci get system.@system[0].hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null || echo backup)"
        echo "=== to_backup.txt ==="; cat ~/to_backup.txt
        echo "=== to_exclude.txt ==="; cat ~/to_exclude.txt
    ' 2>/dev/null)
    if [ -z "$REMOTE_INFO" ]; then
        echo "Error de conexión con $SERVER"; exit 1
    fi
    HOSTNAME=$(echo "$REMOTE_INFO" | sed -n 's/^HOSTNAME://p')
    [ -z "$HOSTNAME" ] && HOSTNAME="backup"
    echo "$REMOTE_INFO" | grep -v "^HOSTNAME:"
    echo "Destino: ${HOSTNAME}-${DATE}.tgz (Incluye .gitignore remotos)"
    exit 0
fi
# 3. Modo Real
ARCHIVE_DATA=$(ssh -n "$SERVER" '
    [ ! -f ~/to_backup.txt ] && echo "$HOME" > ~/to_backup.txt
    [ ! -f ~/to_exclude.txt ] && echo ".cache/" > ~/to_exclude.txt

    HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null || echo backup)
    echo "HOSTNAME:$HOSTNAME"

    EXCLUDE_ARGS=""
    while read -r exclude || [ -n "$exclude" ]; do
        [ -n "$exclude" ] && EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=$exclude"
    done < ~/to_exclude.txt

    BACKUP_FILES=""
    while read -r file || [ -n "$file" ]; do
        [ -n "$file" ] && BACKUP_FILES="$BACKUP_FILES $file"
    done < ~/to_backup.txt

    echo "START_TAR"
    if [ -n "$BACKUP_FILES" ]; then
        tar -czf - --exclude-vcs-ignores $EXCLUDE_ARGS $BACKUP_FILES 2>/dev/null
    fi
')
# 4. Procesar la salida recibida
HOSTNAME=$(echo "$ARCHIVE_DATA" | sed -n 's/^HOSTNAME://p')
[ -z "$HOSTNAME" ] && HOSTNAME="backup"
BACKUP_FILE="${HOSTNAME}-${DATE}.tgz"
echo "$ARCHIVE_DATA" | sed '1,/START_TAR/d' > "$BACKUP_FILE"
echo "OK: $BACKUP_FILE"
echo "Ver: tar -tzf $BACKUP_FILE | awk -F/ '{for(i=1;i<NF;i++) printf(\"%s%s\", \"  \", (i==NF-1)?\"--- \":\"  \"); print \$NF}'"
