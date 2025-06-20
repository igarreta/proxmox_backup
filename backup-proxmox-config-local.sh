#!/bin/bash

# Configuración
BACKUP_DIR="/root/proxmox_backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="proxmox-config-$DATE.tar.gz"
LOG_FILE="/var/log/proxmox-config-backup.log"

# Crear directorio si no existe
mkdir -p $BACKUP_DIR

echo "$(date): Iniciando backup local de configuración Proxmox" | tee -a $LOG_FILE

# Crear backup comprimido
tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
    --exclude='/etc/pve/.version' \
    --exclude='/etc/pve/.members' \
    --exclude='/etc/pve/.clusterlog' \
    /etc/pve/ \
    /etc/network/interfaces \
    /etc/hosts \
    /etc/hostname \
    /etc/fstab \
    /etc/crontab \
    /etc/apt/sources.list \
    /etc/apt/sources.list.d/ \
    /etc/postfix/ \
    /etc/vzdump.conf \
    /root/.ssh/ \
    2>>$LOG_FILE

# Verificar backup
if [ $? -eq 0 ]; then
    echo "$(date): ✓ Backup local creado: $BACKUP_FILE" | tee -a $LOG_FILE
    SIZE=$(ls -lh "$BACKUP_DIR/$BACKUP_FILE" | awk '{print $5}')
    echo "$(date): Tamaño del backup: $SIZE" | tee -a $LOG_FILE
    
    # Limpiar backups antiguos (mantener últimos 7)
    cd $BACKUP_DIR
    ls -t proxmox-config-*.tar.gz | tail -n +8 | xargs -r rm
    echo "$(date): Limpieza de backups antiguos completada" | tee -a $LOG_FILE
else
    echo "$(date): ✗ ERROR: Falló la creación del backup local" | tee -a $LOG_FILE
    exit 1
fi

# Crear lista de contenido
tar -tzf "$BACKUP_DIR/$BACKUP_FILE" > "$BACKUP_DIR/contenido-$DATE.txt"
echo "$(date): Backup local de configuración completado" | tee -a $LOG_FILE