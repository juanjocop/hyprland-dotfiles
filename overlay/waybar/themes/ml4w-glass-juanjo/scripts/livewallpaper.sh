#!/usr/bin/env bash
# livewallpaper.sh — enciende/apaga el fondo de vídeo (mpvpaper) desde un botón de waybar.
# Sin service ni autostart: solo corre cuando lo activas con el botón; al reiniciar sesión
# arranca apagado. Uso: status (JSON para waybar) | toggle (alterna y refresca el módulo).
#
# Config (sobreescribible por variables de entorno):
FOLDER="${LIVE_WALLPAPER_FOLDER:-$HOME/Vídeos/Hidamari}"   # carpeta de vídeos (NO versionada)
MONITOR="${LIVE_WALLPAPER_MONITOR:-eDP-1}"
INTERVAL="${LIVE_WALLPAPER_INTERVAL:-300}"                 # segundos entre cambios de vídeo
SIGNAL=8                                                   # = "signal" del módulo (refresco)

is_running() { pgrep -x mpvpaper >/dev/null 2>&1; }

start() {
    shopt -s nullglob
    local vids=("$FOLDER"/*.mp4 "$FOLDER"/*.mkv "$FOLDER"/*.webm)
    if (( ${#vids[@]} == 0 )); then
        notify-send -a "Live wallpaper" "Sin vídeos en $FOLDER" 2>/dev/null
        return 1
    fi
    # setsid -f: mpvpaper sobrevive al cierre del shell del on-click.
    # Rotación aleatoria (--shuffle) cambiando cada INTERVAL s; cada vídeo loopea entretanto.
    # VAAPI en la iGPU (no despierta la NVIDIA) + auto-pause (-p) cuando una ventana lo tapa.
    setsid -f mpvpaper -n "$INTERVAL" \
        -o "no-audio --hwdec=auto --loop-file=inf --loop-playlist=inf --shuffle" \
        -p "$MONITOR" "$FOLDER" >/dev/null 2>&1
    # Esperar a que aparezca para que el refresco del icono refleje el estado real.
    for _ in $(seq 15); do is_running && break; sleep 0.1; done
}

stop() {
    pkill -x mpvpaper 2>/dev/null || true
    # Esperar a que muera (evita que waybar relea "ON" mientras aún cierra).
    for _ in $(seq 15); do is_running || break; sleep 0.1; done
}

case "${1:-status}" in
    toggle)
        if is_running; then stop; else start || true; fi
        pkill -RTMIN+"$SIGNAL" waybar 2>/dev/null || true
        ;;
    status|*)
        if is_running; then
            printf '{"text":"󰕧","tooltip":"Fondo de vídeo: ON — clic para apagar","class":"active"}\n'
        else
            printf '{"text":"󰕧","tooltip":"Fondo de vídeo: OFF — clic para encender","class":"inactive"}\n'
        fi
        ;;
esac
