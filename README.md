# Backup Automático de Configuración Proxmox

## Resumen del Proyecto

Sistema automatizado de backup para la configuración crítica de servidores Proxmox VE. Este proyecto incluye scripts para respaldar automáticamente todos los archivos de configuración importantes del sistema, con rotación automática de backups y programación mediante cron.

### Características principales:

- **Backup automático** de configuración PVE, red, sistema y servicios
- **Rotación automática** con retención configurable
- **Tres tipos de backup**: diario, semanal y mensual
- **Verificación de integridad** automática
- **Logging completo** de todas las operaciones
- **Script de exploración** para facilitar la gestión de backups

## Estructura del Sistema

```
/mnt/backup_usb1/proxmox-config/
├── daily/                          # Backups diarios (7 días de retención)
├── weekly/                         # Backups semanales (4 semanas de retención)
├── monthly/                        # Backups mensuales (12 meses de retención)
└── scripts/
    ├── backup-config.sh            # Script principal de backup
    └── explore-backup.sh           # Script para explorar backups
```

## Instalación

### Prerrequisitos

- Servidor Proxmox VE
- Disco de backup montado en `/mnt/backup_usb1/`
- Acceso root al servidor

### Pasos de instalación

1. **Crear la estructura de directorios:**
   ```bash
   mkdir -p /mnt/backup_usb1/proxmox-config/{daily,weekly,monthly,scripts}
   ```

2. **Copiar los scripts:**
   ```bash
   # Copiar backup-config.sh y explore-backup.sh a:
   cp backup-config.sh /mnt/backup_usb1/proxmox-config/scripts/
   cp explore-backup.sh /mnt/backup_usb1/proxmox-config/scripts/
   
   # Dar permisos de ejecución
   chmod +x /mnt/backup_usb1/proxmox-config/scripts/*.sh
   ```

3. **Crear archivo de log:**
   ```bash
   touch /var/log/proxmox-config-backup.log
   ```

4. **Configurar programación automática (ver sección "Configuración de Cron" más abajo)**

5. **Probar la instalación:**
   ```bash
   /mnt/backup_usb1/proxmox-config/scripts/backup-config.sh daily
   ```

## Uso del Sistema

### Backup Manual

```bash
# Crear backup diario
/mnt/backup_usb1/proxmox-config/scripts/backup-config.sh daily

# Crear backup semanal
/mnt/backup_usb1/proxmox-config/scripts/backup-config.sh weekly

# Crear backup mensual
/mnt/backup_usb1/proxmox-config/scripts/backup-config.sh monthly
```

### Explorar Backups

```bash
# Listar backups disponibles
/mnt/backup_usb1/proxmox-config/scripts/explore-backup.sh daily list

# Ver contenido del backup más reciente
/mnt/backup_usb1/proxmox-config/scripts/explore-backup.sh daily show

# Extraer backup para exploración
/mnt/backup_usb1/proxmox-config/scripts/explore-backup.sh daily extract

# Ver archivo específico dentro del backup
/mnt/backup_usb1/proxmox-config/scripts/explore-backup.sh daily view system-info.txt
```

### Monitoreo

```bash
# Ver log de operaciones
tail -f /var/log/proxmox-config-backup.log

# Ver últimas 50 líneas del log
tail -n 50 /var/log/proxmox-config-backup.log

# Verificar estado del cron
crontab -l
```

## Recuperación de Información

### Contenido Respaldado

El sistema respalda automáticamente:

- **Configuración PVE**: `/etc/pve/` (VMs, contenedores, usuarios, red del cluster)
- **Configuración de red**: `/etc/network/interfaces`, `/etc/hosts`, `/etc/hostname`
- **Configuración del sistema**: `/etc/fstab`, `/etc/crontab`, `/etc/cron.d/`
- **Configuración SSH**: `/etc/ssh/sshd_config`, `/etc/ssh/ssh_config`
- **Servicios systemd**: servicios personalizados de `/etc/systemd/system/`
- **Información del sistema**: versión, kernel, uptime, discos

### Recuperar un Archivo Específico

1. **Listar archivos disponibles en el backup:**
   ```bash
   LATEST_BACKUP=$(ls -t /mnt/backup_usb1/proxmox-config/daily/proxmox-config-*.tar.gz | head -n 1)
   tar -tzf "$LATEST_BACKUP"
   ```

2. **Extraer un archivo específico:**
   ```bash
   # Ejemplo: recuperar interfaces de red
   tar -xzf "$LATEST_BACKUP" -O proxmox-config/interfaces > /tmp/interfaces_backup
   
   # Ejemplo: recuperar configuración de VM 100
   tar -xzf "$LATEST_BACKUP" -O proxmox-config/pve/qemu-server/100.conf > /tmp/vm100_backup.conf
   ```

3. **Comparar archivo actual con backup:**
   ```bash
   # Extraer y comparar
   tar -xzf "$LATEST_BACKUP" -O proxmox-config/interfaces > /tmp/interfaces_backup
   diff /etc/network/interfaces /tmp/interfaces_backup
   ```

### Restauración Completa en Servidor Nuevo

#### Preparación del servidor nuevo:

1. **Instalar Proxmox VE** en el servidor nuevo
2. **Montar el disco de backup** en `/mnt/backup_usb1/`
3. **Extraer el backup más reciente:**
   ```bash
   cd /tmp
   LATEST_BACKUP=$(ls -t /mnt/backup_usb1/proxmox-config/monthly/proxmox-config-*.tar.gz | head -n 1)
   tar -xzf "$LATEST_BACKUP"
   ```

#### Proceso de restauración:

1. **Detener servicios críticos:**
   ```bash
   systemctl stop pveproxy
   systemctl stop pvedaemon
   systemctl stop pvestatd
   ```

2. **Restaurar configuración de red:**
   ```bash
   cp /tmp/proxmox-config/interfaces /etc/network/interfaces
   cp /tmp/proxmox-config/hosts /etc/hosts
   cp /tmp/proxmox-config/hostname /etc/hostname
   ```

3. **Restaurar configuración PVE:**
   ```bash
   # CUIDADO: Esto sobrescribirá toda la configuración PVE
   cp -r /tmp/proxmox-config/pve/* /etc/pve/
   ```

4. **Restaurar otras configuraciones:**
   ```bash
   cp /tmp/proxmox-config/fstab /etc/fstab
   cp /tmp/proxmox-config/crontab /etc/crontab
   
   # SSH (opcional)
   cp /tmp/proxmox-config/ssh/* /etc/ssh/
   
   # Servicios systemd personalizados
   cp /tmp/proxmox-config/systemd/* /etc/systemd/system/
   ```

5. **Reiniciar servicios:**
   ```bash
   systemctl daemon-reload
   systemctl start pveproxy
   systemctl start pvedaemon
   systemctl start pvestatd
   ```

6. **Reiniciar el servidor:**
   ```bash
   reboot
   ```

#### Verificación post-restauración:

```bash
# Verificar servicios PVE
systemctl status pveproxy pvedaemon pvestatd

# Verificar configuración de red
ip addr show

# Verificar VMs y contenedores
qm list
pct list

# Verificar storages
pvesm status
```

## Configuración de Cron

### Configuración Recomendada

1. **Abrir el editor de crontab:**
   ```bash
   crontab -e
   ```

2. **Agregar las líneas de backup:**
   ```cron
   # Backup de configuración Proxmox
   # Backup diario a las 2:00 AM
   0 2 * * * /mnt/backup_usb1/proxmox-config/scripts/backup-config.sh daily >/dev/null 2>&1
   
   # Backup semanal los domingos a las 3:00 AM
   0 3 * * 0 /mnt/backup_usb1/proxmox-config/scripts/backup-config.sh weekly >/dev/null 2>&1
   
   # Backup mensual el primer día del mes a las 4:00 AM
   0 4 1 * * /mnt/backup_usb1/proxmox-config/scripts/backup-config.sh monthly >/dev/null 2>&1
   ```

3. **Guardar y salir:**
   - En nano: `Ctrl+X`, luego `Y`, luego `Enter`
   - En vim: `Esc`, luego `:wq`, luego `Enter`

### Verificar la Configuración de Cron

```bash
# Ver crontab actual
crontab -l

# Verificar que el servicio cron está ejecutándose
systemctl status cron

# Ver logs de cron (para verificar ejecuciones)
grep CRON /var/log/syslog | tail -10
```

### Configuración con Logs Detallados

Si quieres ver los logs de cron por separado:

```cron
# Backup con logs separados
0 2 * * * /mnt/backup_usb1/proxmox-config/scripts/backup-config.sh daily >> /var/log/cron-backup.log 2>&1
0 3 * * 0 /mnt/backup_usb1/proxmox-config/scripts/backup-config.sh weekly >> /var/log/cron-backup.log 2>&1
0 4 1 * * /mnt/backup_usb1/proxmox-config/scripts/backup-config.sh monthly >> /var/log/cron-backup.log 2>&1
```

### Monitoreo de Ejecuciones de Cron

```bash
# Ver últimas ejecuciones de cron
grep "backup-config.sh" /var/log/syslog | tail -5

# Verificar si cron ejecutó los backups hoy
grep "$(date +%Y-%m-%d)" /var/log/proxmox-config-backup.log

# Ver próximas ejecuciones programadas (requiere el paquete 'cron-utils' o script personalizado)
crontab -l | grep backup-config
```

## Configuración

### Modificar Retención de Backups

Editar el script `backup-config.sh` y modificar estos valores en la función `main()`:

```bash
case "$backup_type" in
    daily)
        cleanup_backups "daily" 7      # Cambiar 7 por días deseados
        ;;
    weekly)
        cleanup_backups "weekly" 4     # Cambiar 4 por semanas deseadas
        ;;
    monthly)
        cleanup_backups "monthly" 12   # Cambiar 12 por meses deseados
        ;;
esac
```

### Agregar Archivos Adicionales al Backup

Editar la función `do_backup()` en `backup-config.sh` y agregar:

```bash
# Ejemplo: agregar configuración personalizada
[ -f "/etc/mi-config.conf" ] && cp /etc/mi-config.conf "$config_temp/" 2>/dev/null
```

## Solución de Problemas

### Problemas Comunes

1. **Script no termina la ejecución:**
   ```bash
   # Verificar procesos colgados
   ps aux | grep backup-config.sh
   # Matar proceso si es necesario
   pkill -f backup-config.sh
   ```

2. **Error de permisos:**
   ```bash
   # Verificar permisos del script
   ls -la /mnt/backup_usb1/proxmox-config/scripts/
   # Corregir si es necesario
   chmod +x /mnt/backup_usb1/proxmox-config/scripts/*.sh
   ```

3. **Disco lleno:**
   ```bash
   # Verificar espacio disponible
   df -h /mnt/backup_usb1/
   # Limpiar backups antiguos manualmente si es necesario
   ```

4. **Backup corrupto:**
   ```bash
   # Verificar integridad
   tar -tzf archivo_backup.tar.gz >/dev/null 2>&1
   echo $?  # 0 = OK, != 0 = corrupto
   ```

### Logs y Debugging

```bash
# Ver log en tiempo real
tail -f /var/log/proxmox-config-backup.log

# Buscar errores en el log
grep -i error /var/log/proxmox-config-backup.log

# Ejecutar script en modo debug
bash -x /mnt/backup_usb1/proxmox-config/scripts/backup-config.sh daily
```

## Seguridad

### Recomendaciones

- Los backups contienen **información sensible** (configuraciones de red, certificados)
- **Proteger el acceso** al disco de backup
- **Verificar regularmente** la integridad de los backups
- **Probar la restauración** periódicamente en un entorno de prueba
- **Mantener múltiples copias** en ubicaciones diferentes para backups críticos

### Permisos

```bash
# Verificar permisos seguros
chmod 700 /mnt/backup_usb1/proxmox-config/
chmod 600 /mnt/backup_usb1/proxmox-config/*/*.tar.gz
```

## Licencia y Soporte

Este proyecto está diseñado para uso interno. Para soporte adicional o modificaciones, consultar la documentación de Proxmox VE y las mejores prácticas de backup de sistemas Linux.

### Información de Contacto del Sistema

- **Log de operaciones**: `/var/log/proxmox-config-backup.log`
- **Directorio de scripts**: `/mnt/backup_usb1/proxmox-config/scripts/`
- **Configuración cron**: `crontab -l` (usuario root)