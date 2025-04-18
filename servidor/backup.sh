#!/bin/sh
# Script para realizar backup de un servidor remoto
# basado en to_backup.txt y to_exclude.txt
[ -z "$1" ] && { echo "Uso: $0 <SERVIDOR>"; exit 1; }
SERVER=$1
DATE=$(date +"%Y-%m-%d")
USERDIR=$(ssh "$SERVER" 'echo $HOME')
HOSTNAME=$(ssh "$SERVER" 'hostname')
mkdir -p "$HOSTNAME"
cd "$HOSTNAME" || exit
ssh "$SERVER" '[ ! -f ~/to_backup.txt ] && echo "$HOME" > ~/to_backup.txt'
ssh "$SERVER" '[ ! -f ~/to_exclude.txt ] && echo ".cache/" > ~/to_exclude.txt'
BACKUP_FILES=$(ssh "$SERVER" 'cat ~/to_backup.txt')
EXCLUDE_FILES=$(ssh "$SERVER" 'cat ~/to_exclude.txt')
EXCLUDE_ARGS=""
for exclude in $EXCLUDE_FILES; do
    EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=$exclude"
done
for file in $BACKUP_FILES; do
    scp -r "$SERVER:$file" .
done
tar -czf "../${HOSTNAME}-${DATE}.tgz" $EXCLUDE_ARGS .
cd .. || exit
rm -rf "$HOSTNAME"
echo "#------------------"
echo "# Respaldo completado: ${HOSTNAME}-${DATE}.tgz"
echo "# Puede restaurar los archivos así:"
echo "tar -xzf ${HOSTNAME}-${DATE}.tgz -C /"
echo "# Puede listar el contenido del archivo de respaldo así:"
echo "tar -tzf ${HOSTNAME}-${DATE}.tgz | awk -F/ '{for(i=1;i<NF;i++) printf(\"%s%s\", \"  \", (i==NF-1)?\"--- \":\"  \"); print \$NF}'"
echo "#------------------"
