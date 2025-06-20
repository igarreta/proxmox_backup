# Guía de Backup de Configuración Proxmox

## 1. Identificar USB por UUID

```bash
# Listar dispositivos conectados
lsblk
"Conectado en sdb"

# Ver información detallada de discos
fdisk -l

# Identificar UUID después del formateo
blkid /dev/sdX1

# Verificar UUID específico
blkid -s UUID -o value /dev/sdX1
```

## 2. Formatear USB en ext4

```bash
# Desmontar dispositivo (si está montado)
umount /dev/sdX* 2>/dev/null

# Crear tabla de particiones GPT
parted /dev/sdX --script -- mklabel gpt

# Crear partición primaria
parted /dev/sdX --script -- mkpart primary ext4 0% 100%

# Formatear en ext4 con optimizaciones
mkfs.ext4 -L "ProxmoxBackup" -m 1 /dev/sdX1

# Verificar formateo
blkid /dev/sdX1
```

## 3. Montar en fstab

```bash
# Crear punto de montaje
mkdir -p /mnt/backup_usb1

# Obtener UUID del dispositivo
UUID=$(blkid -s UUID -o value /dev/sdX1)

# Agregar entrada a fstab
echo "UUID=$UUID /mnt/backup_usb1 ext4 defaults,nofail,noatime 0 2" >> /etc/fstab

# Montar dispositivo
mount -a

# Verificar montaje
df -h /mnt/backup_usb1
mount | grep backup_usb1
```

## 4. Configurar Storage en Proxmox

**Desde la interfaz web:**

1. **Datacenter** → **Storage** → **Add** → **Directory**
2. Configurar parámetros:
   - **ID**: `backup-usb-1tb`
   - **Directory**: `/mnt/backup_usb1`
   - **Content**: ✓ VZDump backup files
   - **Shared**: No
   - **Enable**: ✓ Sí
   - **Max Backups**: 10

**Verificación:**
```bash
# Verificar configuración
cat /etc/pve/storage.cfg | grep -A5 backup-usb

# Probar escritura
touch /mnt/backup_usb1/test.txt && rm /mnt/backup_usb1/test.txt
```

## 5. Scripts de Backup de Configuración

### Script principal para backup local

```bash
# Crear archivo: /root/proxmox_backup/backup-proxmox-config-local.sh
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
```

### Script para backup en USB

```bash
# Crear archivo: /root/proxmox_backup/backup-proxmox-config-usb.sh
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
```

### Script de verificación de backups

```bash
# Crear archivo: /root/proxmox_backup/verify-config-backups.sh
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
```

### Hacer scripts ejecutables

```bash
# Crear directorio de scripts
mkdir -p /root/proxmox_backup

# Hacer scripts ejecutables
chmod +x /root/proxmox_backup/backup-proxmox-config-local.sh
chmod +x /root/proxmox_backup/backup-proxmox-config-usb.sh
chmod +x /root/proxmox_backup/verify-config-backups.sh

# Crear directorio para logs
touch /var/log/proxmox-config-backup.log
```

## 6. Automatización con Crontab

```bash
# Editar crontab
crontab -e

# Agregar las siguientes líneas:

# Backup local diario a las 1:30 AM
30 1 * * * /root/proxmox_backup/backup-proxmox-config-local.sh >/dev/null 2>&1

# Backup USB semanal (domingos a las 2:30 AM)
30 2 * * 0 /root/proxmox_backup/backup-proxmox-config-usb.sh >/dev/null 2>&1

# Verificación de backups diaria a las 6 AM
0 6 * * * /root/proxmox_backup/verify-config-backups.sh >/dev/null 2>&1

# Limpieza de logs mensual (primer día del mes a las 3 AM)
0 3 1 * * echo "" > /var/log/proxmox-config-backup.log
```

### Verificar crontab

```bash
# Verificar configuración
crontab -l

# Ver logs de cron
tail -f /var/log/cron.log

# Ver logs de backup
tail -f /var/log/proxmox-config-backup.log
```

## 7. Instrucciones de Restauración

### Restauración completa en instalación nueva

```bash
# 1. Montar USB o acceder a backup
mount /dev/sdX1 /mnt/backup_usb1

# 2. Localizar backup más reciente
BACKUP_FILE=$(ls -t /mnt/backup_usb1/proxmox_backup/proxmox-config-*.tar.gz | head -1)
echo "Restaurando desde: $BACKUP_FILE"

# 3. Detener servicios Proxmox
systemctl stop pve-cluster pvedaemon pveproxy pvestatd

# 4. Crear backup de configuración actual (por seguridad)
tar -czf /root/config-backup-pre-restore-$(date +%Y%m%d_%H%M%S).tar.gz /etc/pve/

# 5. Restaurar configuración
cd /
tar -xzf "$BACKUP_FILE"

# 6. Ajustar permisos críticos
chown -R root:www-data /etc/pve/
chmod 755 /etc/pve/
chmod 640 /etc/pve/user.cfg
chmod 600 /root/.ssh/id_* 2>/dev/null || true

# 7. Reiniciar servicios
systemctl start pve-cluster
sleep 10
systemctl start pvedaemon pveproxy pvestatd

# 8. Verificar funcionamiento
pvecm status 2>/dev/null || echo "Cluster no configurado"
pvesm status
```

### Restauración selectiva de componentes

```bash
# Solo configuración de VMs
tar -xzf "$BACKUP_FILE" etc/pve/qemu-server/
tar -xzf "$BACKUP_FILE" etc/pve/lxc/
systemctl restart pvedaemon

# Solo configuración de red
tar -xzf "$BACKUP_FILE" etc/network/interfaces
systemctl restart networking

# Solo configuración de storage
tar -xzf "$BACKUP_FILE" etc/pve/storage.cfg
systemctl restart pvedaemon

# Solo usuarios y permisos
tar -xzf "$BACKUP_FILE" etc/pve/user.cfg
systemctl restart pvedaemon
```

### Verificación post-restauración

```bash
# Verificar servicios
systemctl status pve-cluster pvedaemon pveproxy pvestatd

# Verificar conectividad web
curl -k https://localhost:8006 >/dev/null 2>&1 && echo "Web UI disponible"

# Verificar configuraciones
pvesm status
qm list
pct list

# Verificar logs por errores
journalctl -u pve* --since "10 minutes ago" | grep -i error
```

## 8. Verificaciones importantes

### Antes de implementar

```bash
# Verificar espacio disponible
df -h /root
df -h /mnt/backup_usb1

# Probar scripts manualmente
/root/proxmox_backup/backup-proxmox-config-local.sh
/root/proxmox_backup/verify-config-backups.sh

# Verificar montaje USB persistente
umount /mnt/backup_usb1
mount -a
mountpoint /mnt/backup_usb1
```

### Monitoreo continuo

```bash
# Verificar últimos backups
ls -la /root/proxmox_backup/proxmox-config-*.tar.gz | tail -5
ls -la /mnt/backup_usb1/proxmox_backup/proxmox-config-*.tar.gz | tail -5

# Verificar logs de backup
tail -20 /var/log/proxmox-config-backup.log

# Verificar tareas de cron
grep -i backup /var/log/cron.log | tail -5
```