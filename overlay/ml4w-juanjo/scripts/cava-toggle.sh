#!/usr/bin/env bash
# cava-toggle.sh — abre/cierra el visualizador cava. Lo llama SUPER+SHIFT+C
# (ver overlay/hypr/custom.lua). Se despliega a ~/.config/ml4w-juanjo/scripts/ (namespace
# propio, fuera del árbol de ML4W → cero deriva).
#
# El visualizador es una ventana NORMAL: nace tilada en el workspace actual y se coloca con
# las demás (mover, redimensionar, mandar a otro workspace: atajos normales de Hyprland).
# No hay workspace especial ni window_rule: sin regla, Hyprland ya la tila donde toca.
#
# Cerrar = matar cava, NO cerrar la ventana: kitty se cierra sola cuando muere el proceso que
# lanzó con -e. Se evita así depender del targeting de `hl.dsp.window.close`, cuya forma de
# apuntar a una ventana concreta no está documentada en la API Lua de Hyprland 0.55 y que, si
# ignorase el argumento, cerraría la ventana ACTIVA (la del usuario).
#
# Consultar el estado con `pgrep cava` (= "¿está consumiendo?") es justo la condición que
# importa en un portátil, y además se autocura si queda un cava huérfano sin ventana.
#
# Nota: `pkill -x cava` mata cualquier cava, incluido uno lanzado a mano en otra terminal.
# Es lo deseable: el objetivo es que no quede nada consumiendo.
set -euo pipefail

CLASS="cava-visualizer"

if pgrep -x cava >/dev/null; then
    pkill -x cava
else
    kitty --class "$CLASS" -e cava >/dev/null 2>&1 &
fi
