#!/bin/bash

# Script para explorar backups de configuración Proxmox
# Uso: ./explore-backup.sh [daily|weekly|monthly] [list|show|extract]

BACKUP_BASE="/mnt/backup_usb1/proxmox-config"

show_usage() {
    echo "Uso: $0 [daily|weekly|monthly] [list|show|extract] [archivo_opcional]"
    echo ""
    echo "Comandos:"
    echo "  list   - Listar backups disponibles"
    echo "  show   - Mostrar contenido del backup más reciente (o especificado)"
    echo "  extract- Extraer backup en /tmp para exploración"
    echo ""
    echo "Ejemplos:"
    echo "  $0 daily list                    # Listar backups diarios"
    echo "  $0 daily show                    # Mostrar contenido del backup diario más reciente"
    echo "  $0 weekly show backup.tar.gz     # Mostrar contenido de backup específico"
    echo "  $0 monthly extract               # Extraer backup mensual más reciente"
}

list_backups() {
    local backup_type=$1
    local backup_dir="$BACKUP_BASE/$backup_type"
    
    echo "=== Backups disponibles en $backup_type ==="
    if [ -d "$backup_dir" ]; then
        ls -lht "$backup_dir"/*.tar.gz 2>/dev/null | while read -r line; do
            echo "$line"
        done
    else
        echo "No se encontró el directorio: $backup_dir"
    fi
}

show_backup_content() {
    local backup_type=$1
    local specific_file=$2
    local backup_dir="$BACKUP_BASE/$backup_type"
    
    if [ -n "$specific_file" ]; then
        local backup_file="$backup_dir/$specific_file"
    else
        # Usar el más reciente
        local backup_file=$(ls -t "$backup_dir"/proxmox-config-*.tar.gz 2>/dev/null | head -n 1)
    fi
    
    if [ ! -f "$backup_file" ]; then
        echo "Error: No se encontró el archivo de backup: $backup_file"
        return 1
    fi
    
    echo "=== Contenido de: $(basename "$backup_file") ==="
    echo "Tamaño: $(du -h "$backup_file" | cut -f1)"
    echo "Fecha: $(stat -c %y "$backup_file")"
    echo ""
    echo "Archivos incluidos:"
    tar -tvzf "$backup_file"
}

extract_backup() {
    local backup_type=$1
    local specific_file=$2
    local backup_dir="$BACKUP_BASE/$backup_type"
    
    if [ -n "$specific_file" ]; then
        local backup_file="$backup_dir/$specific_file"
    else
        # Usar el más reciente
        local backup_file=$(ls -t "$backup_dir"/proxmox-config-*.tar.gz 2>/dev/null | head -n 1)
    fi
    
    if [ ! -f "$backup_file" ]; then
        echo "Error: No se encontró el archivo de backup: $backup_file"
        return 1
    fi
    
    local extract_dir="/tmp/proxmox-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$extract_dir"
    
    echo "=== Extrayendo backup en: $extract_dir ==="
    cd "$extract_dir"
    tar -xzf "$backup_file"
    
    echo "Backup extraído exitosamente."
    echo "Para explorar: cd $extract_dir"
    echo "Estructura:"
    find "$extract_dir" -type f | head -20
    echo ""
    echo "Para limpiar después: rm -rf $extract_dir"
}

view_specific_file() {
    local backup_type=$1
    local file_path=$2
    local backup_dir="$BACKUP_BASE/$backup_type"
    
    local backup_file=$(ls -t "$backup_dir"/proxmox-config-*.tar.gz 2>/dev/null | head -n 1)
    
    if [ ! -f "$backup_file" ]; then
        echo "Error: No se encontró archivo de backup"
        return 1
    fi
    
    echo "=== Contenido de $file_path desde $(basename "$backup_file") ==="
    tar -xzf "$backup_file" -O "proxmox-config/$file_path" 2>/dev/null || echo "Archivo no encontrado en el backup"
}

# Función principal
main() {
    local backup_type=${1:-""}
    local command=${2:-""}
    local specific_file=${3:-""}
    
    # Validar backup type
    case "$backup_type" in
        daily|weekly|monthly)
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
    
    # Ejecutar comando
    case "$command" in
        list)
            list_backups "$backup_type"
            ;;
        show)
            show_backup_content "$backup_type" "$specific_file"
            ;;
        extract)
            extract_backup "$backup_type" "$specific_file"
            ;;
        view)
            if [ -z "$specific_file" ]; then
                echo "Error: Especifica el archivo a ver dentro del backup"
                echo "Ejemplo: $0 daily view system-info.txt"
                exit 1
            fi
            view_specific_file "$backup_type" "$specific_file"
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

main "$@"