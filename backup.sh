#!/bin/sh
[ -z "$1" ] && { echo "Usage: $0 <SERVER>"; exit 1; }
SERVER=$1
DATE=$(date +"%Y-%m-%d")
USERDIR=$(ssh "$SERVER" 'echo $HOME')
HOSTNAME=$(ssh "$SERVER" 'hostname')
mkdir -p "$HOSTNAME"
cd "$HOSTNAME" || exit
ssh "$SERVER" 'crontab -l' > crontab_user.txt
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
echo "# Backup completed: ${HOSTNAME}-${DATE}.tgz"
echo "# To restore the backup on the remote server, run:"
echo "tar -xzf ${HOSTNAME}-${DATE}.tgz -C /"
echo "# To list the contents of the tarball in an ordered way, run:"
echo "tar -tzf ${HOSTNAME}-${DATE}.tgz | awk -F/ '{for(i=1;i<NF;i++) printf(\"%s%s\", \"  \", (i==NF-1)?\"--- \":\"  \"); print \$NF}'"
echo "#------------------"
