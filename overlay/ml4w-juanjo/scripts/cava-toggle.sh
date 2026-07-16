#!/usr/bin/env bash
# cava-toggle.sh — enciende/apaga el visualizador de audio, en uno de sus dos modos:
#
#   cava-toggle.sh tile   → SUPER+SHIFT+C: cava en una ventana kitty, tilada en el workspace actual.
#   cava-toggle.sh bg     → SUPER+ALT+C:   franja de barras en el fondo (widget Quickshell),
#                                          sobre el vídeo de mpvpaper y bajo las ventanas.
#
# Los dos modos son EXCLUYENTES: encender uno apaga el otro. No tiene sentido tener dos
# visualizadores pintando la misma información, y así nunca hay dos cavas compitiendo.
# Un único script en vez de dos para que la lógica de exclusión viva en un solo sitio.
#
# Se despliega a ~/.config/ml4w-juanjo/scripts/ (namespace propio, fuera del árbol de ML4W).
#
# IMPORTANTE — por qué se apunta con `pgrep -f <patrón>` y no con `pgrep -x cava`:
# ambos modos lanzan un proceso `cava`, así que razonar sobre "cualquier cava" mataría el del
# otro modo (y también el de un cava lanzado a mano, o el de un cava-bg si algún día se instala).
# Cada modo apunta solo a SU proceso. `pgrep -x cava` no debe volver a aparecer aquí.
#
# Cerrar el tile = matar su kitty; cava muere con ella (es su proceso hijo vía `-e`).
set -euo pipefail

MODE="${1:-tile}"

TILE_PAT="kitty --class cava-visualizer"
BG_PAT="qs -p .*/ml4w-juanjo/quickshell/cavabg"
BG_DIR="$HOME/.config/ml4w-juanjo/quickshell/cavabg"

tile_running() { pgrep -f "$TILE_PAT" >/dev/null; }
bg_running() { pgrep -f "$BG_PAT" >/dev/null; }

stop_tile() { pkill -f "$TILE_PAT" 2>/dev/null || true; }
stop_bg() { pkill -f "$BG_PAT" 2>/dev/null || true; }

start_tile() { kitty --class cava-visualizer -e cava >/dev/null 2>&1 & }
start_bg() { qs -p "$BG_DIR" >/dev/null 2>&1 & }

case "$MODE" in
tile)
    if tile_running; then
        stop_tile
    else
        stop_bg
        start_tile
    fi
    ;;
bg)
    if bg_running; then
        stop_bg
    else
        stop_tile
        start_bg
    fi
    ;;
*)
    echo "uso: $(basename "$0") [tile|bg]" >&2
    exit 2
    ;;
esac
