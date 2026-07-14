#!/usr/bin/env bash
# gputemp.sh — temperatura de la dGPU NVIDIA sin despertarla (portátil Optimus).
# Leer runtime_status es un read de sysfs y NO despierta la GPU; nvidia-smi solo se
# invoca si la dGPU ya está "active". Si duerme, mostramos el icono de reposo.
status=$(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null)
if [ "$status" = "active" ]; then
    t=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
    if [ -n "$t" ]; then
        echo "󰢮 ${t}°C"
    else
        echo "󰢮 --"
    fi
else
    # dGPU dormida: no la despertamos
    echo "󰢮 󰤄"
fi
