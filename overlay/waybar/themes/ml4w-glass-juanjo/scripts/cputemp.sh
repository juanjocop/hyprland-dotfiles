#!/usr/bin/env bash
# cputemp.sh — temperatura de la CPU, resolviendo el sensor por NOMBRE de hwmon.
#
# Sustituye al módulo `temperature` nativo de waybar. Aquel obliga a fijar `hwmon-path-abs`, y
# esa ruta es justo lo que cambia entre los dos equipos:
#   · portátil (Intel)  → /sys/devices/platform/coretemp.0/hwmon
#   · sobremesa (AMD)   → /sys/devices/pci0000:00/0000:00:18.3/hwmon
# Y `hwmonN` tampoco es estable entre arranques (por eso se usaba `hwmon-path-abs`). Buscar por
# `name` resuelve las dos cosas a la vez y deja UN SOLO overlay válido en ambas máquinas.
#
# En los dos chips el sensor bueno es temp1_input: "Tctl" en k10temp (AMD), "Package id 0" en
# coretemp (Intel).

CRIT="${CPU_TEMP_CRITICAL:-85}" # = el critical-threshold que traía el módulo nativo

# Primer hwmon cuyo `name` case y que tenga temp1_input legible. El orden de preferencia da
# igual en la práctica (una máquina tiene uno u otro, nunca los dos).
find_hwmon() {
    local want d name
    for want in k10temp coretemp; do
        for d in /sys/class/hwmon/hwmon*; do
            name=$(cat "$d/name" 2>/dev/null) || continue
            if [ "$name" = "$want" ] && [ -r "$d/temp1_input" ]; then
                echo "$d"
                return 0
            fi
        done
    done
    return 1
}

hw=$(find_hwmon)
if [ -z "$hw" ]; then
    printf '{"text":"󰔏 --","tooltip":"CPU: sin sensor k10temp/coretemp","class":"normal"}\n'
    exit 0
fi

raw=$(cat "$hw/temp1_input" 2>/dev/null)
if [ -z "$raw" ]; then
    printf '{"text":"󰔏 --","tooltip":"CPU: sensor ilegible","class":"normal"}\n'
    exit 0
fi

t=$((raw / 1000))
chip=$(cat "$hw/name" 2>/dev/null)
label=$(cat "$hw/temp1_label" 2>/dev/null) # Tctl / Package id 0; puede no existir

[ -n "$label" ] && sensor="$chip/$label" || sensor="$chip"

# Mismos dos iconos que tenía el módulo nativo en format / format-critical.
if [ "$t" -ge "$CRIT" ]; then
    class="critical"
    icon="󰸁"
else
    class="normal"
    icon="󰔏"
fi

printf '{"text":"%s %s°C","tooltip":"CPU %s°C (%s)","class":"%s"}\n' "$icon" "$t" "$t" "$sensor" "$class"
