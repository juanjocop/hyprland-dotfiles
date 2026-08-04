#!/usr/bin/env bash
# livewallpaper.sh — enciende/apaga el fondo de vídeo (mpvpaper) desde un botón de waybar.
# Sin service ni autostart: solo corre cuando lo activas con el botón; al reiniciar sesión
# arranca apagado.
#
# Uso: livewallpaper.sh <status|toggle> [1|2]
#   status  → JSON para waybar        toggle → alterna y refresca los módulos
#   1|2     → "ranura": hay un botón por pantalla y son INDEPENDIENTES (cada uno enciende su
#             propio mpvpaper en su monitor). Por defecto 1. La ranura 2 se oculta sola si no
#             hay segundo monitor conectado.
#
# Preferencias POR MÁQUINA, fuera de git: el overlay es idéntico en todos los equipos, así que
# lo que cambia de uno a otro (qué monitor, qué carpeta) vive aquí. waybar lanza este script sin
# entorno propio, por eso no basta con exportar las variables en el shell.
# shellcheck source=/dev/null
[ -f "$HOME/.config/ml4w-juanjo/local.env" ] && . "$HOME/.config/ml4w-juanjo/local.env"

# Config (sobreescribible por local.env o por variables de entorno):
FOLDER="${LIVE_WALLPAPER_FOLDER:-$HOME/Vídeos/Hidamari}"   # carpeta de vídeos (NO versionada)
INTERVAL="${LIVE_WALLPAPER_INTERVAL:-300}"                 # segundos entre cambios de vídeo
SIGNAL=8                                                   # = "signal" de los dos módulos

# ── Qué monitor le toca a cada ranura ─────────────────────────────────────────────────────────
# El orden es por .id de Hyprland, NO el monitor enfocado: con dos pantallas el foco se mueve
# entre el status y el toggle, las dos ranuras se intercambiarían la identidad y un fondo
# encendido dejaría de poder apagarse desde su propio botón. Con una sola pantalla da igual
# (en el portátil sigue saliendo eDP-1). jq es dependencia de ML4W (lo usa su propio launch.sh).
primer_monitor() {
    hyprctl monitors -j 2>/dev/null | jq -r 'sort_by(.id) | .[0].name // empty' 2>/dev/null
}

# El "otro": el primero por id que no sea el de la ranura 1. Vacío si no hay segunda pantalla.
otro_monitor() {
    hyprctl monitors -j 2>/dev/null |
        jq -r --arg m1 "$1" 'sort_by(.id) | map(select(.name != $m1)) | .[0].name // empty' 2>/dev/null
}

monitor_de_ranura() {
    local m1="${LIVE_WALLPAPER_MONITOR:-$(primer_monitor)}"
    case "$1" in
        2) printf '%s' "${LIVE_WALLPAPER_MONITOR_2:-$(otro_monitor "$m1")}" ;;
        *) printf '%s' "$m1" ;;
    esac
}

# ── Estado POR MONITOR ────────────────────────────────────────────────────────────────────────
# Nada de `pgrep -x mpvpaper` / `pkill -x mpvpaper`: eso es global y un botón apagaría el fondo
# del otro monitor. La salida es el penúltimo argumento de mpvpaper (…  -p DP-1 /carpeta), así
# que se lee /proc/PID/cmdline —separado por NUL— en vez de casar la línea con pgrep -f: así ni
# DP-1 casa con un DP-10 ni se rompe si la carpeta de vídeos lleva espacios.
pid_en_monitor() {
    local pid args
    for pid in $(pgrep -x mpvpaper 2>/dev/null); do
        mapfile -d '' -t args < "/proc/$pid/cmdline" 2>/dev/null || continue
        (( ${#args[@]} >= 2 )) && [[ ${args[-2]} == "$1" ]] && { printf '%s' "$pid"; return 0; }
    done
    return 1
}

is_running() { pid_en_monitor "$1" >/dev/null 2>&1; }

start() {
    local mon="$1"
    if [ -z "$mon" ]; then
        notify-send -a "Live wallpaper" "No hay monitor para esa pantalla" 2>/dev/null
        return 1
    fi
    shopt -s nullglob
    local vids=("$FOLDER"/*.mp4 "$FOLDER"/*.mkv "$FOLDER"/*.webm)
    if (( ${#vids[@]} == 0 )); then
        notify-send -a "Live wallpaper" "Sin vídeos en $FOLDER" 2>/dev/null
        return 1
    fi
    # setsid -f: mpvpaper sobrevive al cierre del shell del on-click.
    # Rotación aleatoria (--shuffle) cambiando cada INTERVAL s; cada vídeo loopea entretanto.
    # Con las dos pantallas encendidas cada instancia baraja por su cuenta → vídeos distintos.
    # VAAPI en la iGPU (no despierta la NVIDIA) + auto-pause (-p) cuando una ventana lo tapa.
    setsid -f mpvpaper -n "$INTERVAL" \
        -o "no-audio --hwdec=auto --loop-file=inf --loop-playlist=inf --shuffle" \
        -p "$mon" "$FOLDER" >/dev/null 2>&1
    # Esperar a que aparezca para que el refresco del icono refleje el estado real.
    for _ in $(seq 15); do is_running "$mon" && break; sleep 0.1; done
}

stop() {
    local mon="$1" pid
    pid="$(pid_en_monitor "$mon")" || return 0
    kill "$pid" 2>/dev/null || true
    # Esperar a que muera (evita que waybar relea "ON" mientras aún cierra).
    for _ in $(seq 15); do is_running "$mon" || break; sleep 0.1; done
}

RANURA="${2:-1}"
MONITOR="$(monitor_de_ranura "$RANURA")"
case "$RANURA" in 2) SUPER="²" ;; *) SUPER="¹" ;; esac

case "${1:-status}" in
    toggle)
        if is_running "$MONITOR"; then stop "$MONITOR"; else start "$MONITOR" || true; fi
        # Una sola señal: los dos módulos usan la 8, así que cada clic refresca ambos (y de paso
        # reevalúa si el segundo botón debe verse).
        pkill -RTMIN+"$SIGNAL" waybar 2>/dev/null || true
        ;;
    status|*)
        if [ -z "$MONITOR" ]; then
            # Sin pantalla para esta ranura (portátil, o segundo monitor desconectado): texto
            # vacío → waybar oculta el módulo entero, no deja un hueco.
            printf '{"text":"","tooltip":"","class":"oculto"}\n'
        elif is_running "$MONITOR"; then
            printf '{"text":"󰕧%s","tooltip":"Fondo de vídeo (%s): ON — clic para apagar","class":"active"}\n' \
                "$SUPER" "$MONITOR"
        else
            printf '{"text":"󰕧%s","tooltip":"Fondo de vídeo (%s): OFF — clic para encender","class":"inactive"}\n' \
                "$SUPER" "$MONITOR"
        fi
        ;;
esac
