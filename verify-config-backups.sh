#!/bin/bash

LOG_FILE="/var/log/proxmox-config-backup.log"

echo "$(date): Iniciando verificación de backups de configuración" | tee -a $LOG_FILE

# Verificar backup local
LOCAL_DIR="/root/proxmox_backup"
if [ -d "$LOCAL_DIR" ]; then
    LATEST_LOCAL=$(ls -t $LOCAL_DIR/proxmox-config-*.tar.gz 2>/dev/null | head -1)
    if [ -f "$LATEST_LOCAL" ]; then
        tar -tzf "$LATEST_LOCAL" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "$(date): ✓ Backup local verificado: $(basename $LATEST_LOCAL)" | tee -a $LOG_FILE
        else
            echo "$(date): ✗ ERROR: Backup local corrupto: $(basename $LATEST_LOCAL)" | tee -a $LOG_FILE
        fi
    else
        echo "$(date): ⚠ ADVERTENCIA: No se encontró backup local" | tee -a $LOG_FILE
    fi
fi

# Verificar backup USB
USB_DIR="/mnt/backup_usb1/proxmox_backup"
if mountpoint -q /mnt/backup_usb1 && [ -d "$USB_DIR" ]; then
    LATEST_USB=$(ls -t $USB_DIR/proxmox-config-*.tar.gz 2>/dev/null | head -1)
    if [ -f "$LATEST_USB" ]; then
        tar -tzf "$LATEST_USB" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "$(date): ✓ Backup USB verificado: $(basename $LATEST_USB)" | tee -a $LOG_FILE
        else
            echo "$(date): ✗ ERROR: Backup USB corrupto: $(basename $LATEST_USB)" | tee -a $LOG_FILE
        fi
    else
        echo "$(date): ⚠ ADVERTENCIA: No se encontró backup USB" | tee -a $LOG_FILE
    fi
else
    echo "$(date): ⚠ ADVERTENCIA: USB no montado o directorio no existe" | tee -a $LOG_FILE
fi

echo "$(date): Verificación de backups completada" | tee -a $LOG_FILE