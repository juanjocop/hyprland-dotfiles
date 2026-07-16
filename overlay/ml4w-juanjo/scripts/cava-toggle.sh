#!/usr/bin/env bash
# cava-toggle.sh — muestra/oculta el visualizador cava. Lo llama SUPER+SHIFT+C
# (ver overlay/hypr/custom.lua). Se despliega a ~/.config/ml4w-juanjo/scripts/ (namespace
# propio, fuera del árbol de ML4W → cero deriva).
#
# Semántica: MATA cava al ocultar en vez de solo esconderlo. En un portátil Optimus no tiene
# sentido gastar CPU dibujando barras que no se ven. Por eso el estado se consulta con
# `pgrep cava` (= "¿está consumiendo?"), que es justo la condición que nos importa; además
# se autocura si alguna vez queda un cava huérfano sin ventana.
#
# Cerrar = matar cava, NO cerrar la ventana: kitty se cierra sola cuando muere el proceso que
# lanzó con -e. Se evita así depender del targeting de `hl.dsp.window.close`, cuya forma de
# apuntar a una ventana concreta no está documentada en la API Lua de Hyprland 0.55 y que, si
# ignorase el argumento, cerraría la ventana ACTIVA (la del usuario).
#
# La ventana va sola a special:cava gracias a la window_rule de custom.lua (clave `workspace`,
# verificada válida con `hyprctl eval`).
#
# Nota: `pkill -x cava` mata cualquier cava, incluido uno lanzado a mano en otra terminal.
# Es lo deseable: el objetivo es que no quede nada consumiendo.
set -euo pipefail

CLASS="cava-visualizer"
WS="cava"

if pgrep -x cava >/dev/null; then
    pkill -x cava
else
    kitty --class "$CLASS" -e cava >/dev/null 2>&1 &
    # OJO: en Hyprland 0.55 con config Lua, `hyprctl dispatch` evalúa su argumento como Lua
    # (lo envuelve en hl.dispatch(...)). La sintaxis de string clásica ya NO funciona.
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$WS\")" >/dev/null
fi
