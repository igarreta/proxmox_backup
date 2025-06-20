#!/bin/bash

# Configuración
USB_BACKUP_DIR="/mnt/backup_usb1/proxmox_backup"
LOCAL_BACKUP_DIR="/root/proxmox_backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="proxmox-config-$DATE.tar.gz"
LOG_FILE="/var/log/proxmox-config-backup.log"

# Crear directorio en USB si no existe
mkdir -p $USB_BACKUP_DIR

echo "$(date): Iniciando backup USB de configuración Proxmox" | tee -a $LOG_FILE

# Verificar que USB está montado
if ! mountpoint -q /mnt/backup_usb1; then
    echo "$(date): ✗ ERROR: USB no está montado" | tee -a $LOG_FILE
    exit 1
fi

# Crear backup comprimido en USB
tar -czf "$USB_BACKUP_DIR/$BACKUP_FILE" \
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
    echo "$(date): ✓ Backup USB creado: $BACKUP_FILE" | tee -a $LOG_FILE
    SIZE=$(ls -lh "$USB_BACKUP_DIR/$BACKUP_FILE" | awk '{print $5}')
    echo "$(date): Tamaño del backup: $SIZE" | tee -a $LOG_FILE
    
    # Sincronizar con backup local (copiar el más reciente)
    if [ -d "$LOCAL_BACKUP_DIR" ]; then
        LATEST_LOCAL=$(ls -t $LOCAL_BACKUP_DIR/proxmox-config-*.tar.gz 2>/dev/null | head -1)
        if [ -f "$LATEST_LOCAL" ]; then
            cp "$LATEST_LOCAL" "$USB_BACKUP_DIR/"
            echo "$(date): Backup local sincronizado al USB" | tee -a $LOG_FILE
        fi
    fi
    
    # Limpiar backups antiguos en USB (mantener últimos 15)
    cd $USB_BACKUP_DIR
    ls -t proxmox-config-*.tar.gz | tail -n +16 | xargs -r rm
    echo "$(date): Limpieza de backups antiguos USB completada" | tee -a $LOG_FILE
else
    echo "$(date): ✗ ERROR: Falló la creación del backup USB" | tee -a $LOG_FILE
    exit 1
fi

# Crear lista de contenido
tar -tzf "$USB_BACKUP_DIR/$BACKUP_FILE" > "$USB_BACKUP_DIR/contenido-$DATE.txt"
echo "$(date): Backup USB de configuración completado" | tee -a $LOG_FILE
