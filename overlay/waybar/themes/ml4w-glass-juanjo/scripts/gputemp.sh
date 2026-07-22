#!/usr/bin/env bash
# gputemp.sh — temperatura de la GPU NVIDIA sin despertarla.
#
# La lógica anti-despertar viene del portátil Optimus y se mantiene intacta: leer
# `runtime_status` es un read de sysfs y NO despierta la GPU; `nvidia-smi` solo se invoca si ya
# está "active". Si duerme, se muestra el icono de reposo.
#
# Lo que ya NO se cablea, para que el mismo fichero valga en las dos máquinas:
#   · la dirección PCI: se resuelve con lspci (clase VGA 0300 o 3D 0302 del fabricante 10de).
#     Da la casualidad de que en ambos equipos es 0000:01:00.0, pero no se asume.
#   · el nombre de la tarjeta: sale de la MISMA llamada a nvidia-smi que la temperatura, así el
#     tooltip dice "GTX 1060 Mobile" o "RTX 5070 Ti" según dónde corra, sin coste extra.

ICON="󰢮"

emit() { printf '{"text":"%s %s","tooltip":"%s","class":"%s"}\n' "$ICON" "$1" "$2" "$3"; }

# Primera GPU NVIDIA (clase VGA 0300 o 3D controller 0302).
addr=$(lspci -D -d 10de: -n 2>/dev/null | awk '$2 ~ /^030[02]:/ { print $1; exit }')

if [ -z "$addr" ]; then
    emit "--" "Sin GPU NVIDIA detectada" "inactive"
    exit 0
fi

# Si el fichero no existe (sobremesa sin runtime PM) se consulta directamente: no hay nada que
# dormir. Solo se frena cuando sysfs dice explícitamente que NO está activa.
status=$(cat "/sys/bus/pci/devices/$addr/power/runtime_status" 2>/dev/null)
if [ -n "$status" ] && [ "$status" != "active" ]; then
    emit "󰤄" "GPU NVIDIA en reposo — no se despierta para leer la temperatura" "inactive"
    exit 0
fi

# Una sola llamada para nombre y temperatura: "NVIDIA GeForce RTX 5070 Ti, 48".
out=$(nvidia-smi --query-gpu=name,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
if [ -z "$out" ]; then
    emit "--" "GPU NVIDIA: nvidia-smi no responde" "inactive"
    exit 0
fi

name="${out%,*}"   # todo lo anterior a la última coma
t="${out##*, }"    # lo que va tras ella

emit "${t}°C" "${name:-GPU NVIDIA} — ${t}°C" "active"
