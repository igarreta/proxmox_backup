#!/bin/bash

# Script de backup de configuración Proxmox
# Uso: ./backup-config.sh [daily|weekly|monthly]

set -e

# Configuración
BACKUP_BASE="/mnt/backup_usb1/proxmox-config"
LOG_FILE="/var/log/proxmox-config-backup.log"
HOSTNAME=$(hostname)
DATE=$(date +%Y%m%d_%H%M%S)

# Función de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Función de cleanup/rotación
cleanup_backups() {
    local backup_type=$1
    local keep_count=$2
    local backup_dir="$BACKUP_BASE/$backup_type"
    
    log "Limpiando backups antiguos en $backup_dir (manteniendo $keep_count)"
    
    # Contar archivos existentes
    local file_count=$(ls -1 "$backup_dir"/proxmox-config-*.tar.gz 2>/dev/null | wc -l || echo "0")
    
    if [ "$file_count" -gt "$keep_count" ]; then
        # Eliminar backups antiguos, manteniendo solo los más recientes
        ls -t "$backup_dir"/proxmox-config-*.tar.gz 2>/dev/null | tail -n +$((keep_count + 1)) | while read -r file; do
            log "Eliminando backup antiguo: $file"
            rm -f "$file"
        done
    else
        log "No hay backups antiguos que eliminar ($file_count archivos, manteniendo $keep_count)"
    fi
}

# Función principal de backup
do_backup() {
    local backup_type=$1
    local backup_dir="$BACKUP_BASE/$backup_type"
    local backup_file="$backup_dir/proxmox-config-${HOSTNAME}-${DATE}.tar.gz"
    
    log "Iniciando backup $backup_type"
    
    # Crear directorio temporal para el backup
    local temp_dir=$(mktemp -d)
    local config_temp="$temp_dir/proxmox-config"
    mkdir -p "$config_temp"
    
    # Copiar archivos de configuración
    log "Copiando archivos de configuración..."
    
    # Configuración PVE (crítica)
    if [ -d "/etc/pve" ]; then
        cp -r /etc/pve "$config_temp/" 2>/dev/null || log "ADVERTENCIA: No se pudo copiar /etc/pve"
    fi
    
    # Configuración de red
    [ -f "/etc/network/interfaces" ] && cp /etc/network/interfaces "$config_temp/" 2>/dev/null
    [ -f "/etc/hosts" ] && cp /etc/hosts "$config_temp/" 2>/dev/null
    [ -f "/etc/hostname" ] && cp /etc/hostname "$config_temp/" 2>/dev/null
    
    # Configuración del sistema
    [ -f "/etc/fstab" ] && cp /etc/fstab "$config_temp/" 2>/dev/null
    [ -f "/etc/crontab" ] && cp /etc/crontab "$config_temp/" 2>/dev/null
    
    # Configuración SSH
    if [ -d "/etc/ssh" ]; then
        mkdir -p "$config_temp/ssh"
        cp /etc/ssh/sshd_config "$config_temp/ssh/" 2>/dev/null || true
        cp /etc/ssh/ssh_config "$config_temp/ssh/" 2>/dev/null || true
    fi
    
    # Cron jobs personalizados
    if [ -d "/etc/cron.d" ]; then
        cp -r /etc/cron.d "$config_temp/" 2>/dev/null || true
    fi
    
    # Servicios systemd personalizados
    if [ -d "/etc/systemd/system" ]; then
        mkdir -p "$config_temp/systemd"
        find /etc/systemd/system -name "*.service" -exec cp {} "$config_temp/systemd/" \; 2>/dev/null || true
    fi
    
    # Crear archivo de información del sistema
    cat > "$config_temp/system-info.txt" << EOF
Backup creado: $(date)
Hostname: $HOSTNAME
Versión Proxmox: $(pveversion)
Kernel: $(uname -r)
Uptime: $(uptime)
Discos: $(df -h)
EOF
    
    # Crear el archivo tar.gz
    log "Creando archivo comprimido..."
    cd "$temp_dir"
    tar -czf "$backup_file" proxmox-config/
    
    # Limpiar directorio temporal
    rm -rf "$temp_dir"
    
    # Verificar que el backup se creó correctamente
    if [ -f "$backup_file" ]; then
        local size=$(du -h "$backup_file" | cut -f1)
        log "Backup completado: $backup_file ($size)"
        
        # Verificar integridad
        if tar -tzf "$backup_file" >/dev/null 2>&1; then
            log "Verificación de integridad: OK"
        else
            log "ERROR: Verificación de integridad falló"
            exit 1
        fi
    else
        log "ERROR: No se pudo crear el archivo de backup"
        exit 1
    fi
}

# Función principal
main() {
    local backup_type=${1:-""}
    
    # Validar parámetro
    case "$backup_type" in
        daily|weekly|monthly)
            ;;
        *)
            echo "Uso: $0 [daily|weekly|monthly]"
            exit 1
            ;;
    esac
    
    # Verificar que el directorio de backup existe
    if [ ! -d "$BACKUP_BASE" ]; then
        log "ERROR: Directorio de backup no existe: $BACKUP_BASE"
        exit 1
    fi
    
    # Verificar espacio disponible (al menos 1GB libre)
    local available_space=$(df "$BACKUP_BASE" | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 1048576 ]; then
        log "ADVERTENCIA: Poco espacio disponible en $BACKUP_BASE"
    fi
    
    log "=== Iniciando backup de configuración Proxmox ($backup_type) ==="
    
    # Realizar backup
    do_backup "$backup_type"
    
    # Limpiar backups antiguos según el tipo
    case "$backup_type" in
        daily)
            cleanup_backups "daily" 7
            ;;
        weekly)
            cleanup_backups "weekly" 4
            ;;
        monthly)
            cleanup_backups "monthly" 12
            ;;
    esac
    
    log "=== Backup completado ==="
}

# Ejecutar función principal
main "$@"

# Salir explícitamente
exit 0