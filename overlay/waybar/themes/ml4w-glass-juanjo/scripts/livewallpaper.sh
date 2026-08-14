#!/usr/bin/env bash
# livewallpaper.sh — fondo de vídeo (mpvpaper) desde botones de waybar.
# Sin service ni autostart: solo corre cuando lo activas con el botón; al reiniciar sesión
# arranca apagado (y en silencio).
#
# Uso: livewallpaper.sh <verbo> [1|2]
#   status | toggle                   → enciende/apaga el fondo de esa pantalla
#   audio-status | audio-toggle       → sonido del vídeo. EXCLUSIVO: encender uno silencia el otro
#   rotacion-status | rotacion-toggle → cambio automático de vídeo cada INTERVAL s
#   saltar-status | saltar            → pasa YA al siguiente vídeo, sin esperar a la rotación
#   1|2  → "ranura": hay un juego de botones por pantalla y son INDEPENDIENTES (cada uno manda
#          sobre su propio mpvpaper). Por defecto 1. La ranura 2 se oculta sola si no hay
#          segundo monitor conectado.
#
# En waybar los tres últimos son los HIJOS del desplegable que cuelga de cada botón `󰕧`, y solo
# se ven si ese fondo de vídeo está encendido.
#
# Preferencias POR MÁQUINA, fuera de git: el overlay es idéntico en todos los equipos, así que
# lo que cambia de uno a otro (qué monitor, qué carpeta) vive aquí. waybar lanza este script sin
# entorno propio, por eso no basta con exportar las variables en el shell.
# shellcheck source=/dev/null
[ -f "$HOME/.config/ml4w-juanjo/local.env" ] && . "$HOME/.config/ml4w-juanjo/local.env"

# Config (sobreescribible por local.env o por variables de entorno):
FOLDER="${LIVE_WALLPAPER_FOLDER:-$HOME/Vídeos/Hidamari}"   # carpeta de vídeos (NO versionada)
INTERVAL="${LIVE_WALLPAPER_INTERVAL:-300}"                 # segundos entre cambios de vídeo
SIGNAL=8                                                   # = "signal" de todos los módulos
TICK=10                                                    # cada cuánto mira el rotador el reloj
CACHE="$HOME/.cache/ml4w-juanjo"

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

# ── Ficheros de estado, uno por monitor ───────────────────────────────────────────────────────
# El estado del icono NO se consulta por IPC: waybar refresca varios módulos a la vez y cada
# ida y vuelta por el socket cuesta décimas. Como los únicos que tocamos mpv somos nosotros,
# basta con anotar aquí lo que hemos hecho. Por IPC solo van los CLICS, donde no se nota.
socket_de_monitor() { printf '%s/mpvpaper-%s.sock' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" "$1"; }
f_audio()           { printf '%s/livewallpaper-audio-%s' "$CACHE" "$1"; }     # 1 = con sonido
f_rotacion()        { printf '%s/livewallpaper-rotacion-%s' "$CACHE" "$1"; }  # 0 = sin rotación
f_ultimo()          { printf '%s/livewallpaper-ultimo-%s' "$CACHE" "$1"; }    # epoch del cambio
f_rotadorpid()      { printf '%s/livewallpaper-rotador-%s.pid' "$CACHE" "$1"; }

marcar_ultimo() { mkdir -p "$CACHE"; date +%s > "$(f_ultimo "$1")"; }

# El audio arranca siempre apagado (mpvpaper se lanza con mute=yes), así que este estado se
# reinicia con cada encendido. La rotación, en cambio, es PEGAJOSA: si la desactivas, sigue
# desactivada la próxima vez que enciendas el fondo.
audio_activo()    { [ "$(cat "$(f_audio "$1")" 2>/dev/null)" = "1" ]; }
rotacion_activa() { [ "$(cat "$(f_rotacion "$1")" 2>/dev/null)" != "0" ]; }

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

# ── Hablar con mpv ────────────────────────────────────────────────────────────────────────────
# El man de mpvpaper documenta este camino: -o "input-ipc-server=…" y luego socat. Permite
# cambiar cosas EN CALIENTE; relanzar mpvpaper cortaría el vídeo, perdería la posición y
# rebarajaría la lista.
#
# -t0.2: mpv también empuja EVENTOS por el socket, así que la conexión no se cierra sola al
# recibir la respuesta; sin recortar esa espera cada clic costaría medio segundo. Y por eso
# mismo hay que quedarse con la primera línea que sea una RESPUESTA: las respuestas llevan
# "error", los eventos no.
ipc() {
    local sock="$1" cmd="$2" resp data
    [ -S "$sock" ] || return 1
    resp="$(printf '%s\n' "$cmd" | socat -t0.2 - "UNIX-CONNECT:$sock" 2>/dev/null)" || return 1
    data="$(printf '%s\n' "$resp" |
        jq -r 'select(.error) | if .error == "success" then (.data|tostring) else "__error__" end' \
        2>/dev/null | head -n1)"
    [ -n "$data" ] && [ "$data" != "__error__" ] || return 1
    printf '%s' "$data"
}

# Siguiente vídeo de la lista. NO se usa "playlist-next": en la última entrada `weak` no hace
# nada y `force` puede terminar la reproducción. Con la posición y el total el salto es
# determinista y da la vuelta al final.
siguiente_video() {
    local mon="$1" sock pos count sig
    sock="$(socket_de_monitor "$mon")"
    pos="$(ipc "$sock" '{"command":["get_property","playlist-pos"]}')"     || return 1
    count="$(ipc "$sock" '{"command":["get_property","playlist-count"]}')" || return 1
    [[ "$pos" =~ ^-?[0-9]+$ && "$count" =~ ^[0-9]+$ ]] && (( count > 0 ))  || return 1
    sig=$(( (pos + 1) % count ))
    ipc "$sock" "$(printf '{"command":["set_property","playlist-pos",%d]}' "$sig")" >/dev/null || return 1
    marcar_ultimo "$mon"
}

# mute es lo contrario del audio. Se usa `mute` y no `aid` a propósito: `mute` es estable aunque
# el vídeo de turno no tenga pista de audio y sobrevive a los cambios de vídeo; con `aid` el
# icono mentiría en cuanto tocase un vídeo mudo.
audio_set() {
    local mon="$1" on="$2" val=true
    [ "$on" = "1" ] && val=false
    ipc "$(socket_de_monitor "$mon")" "{\"command\":[\"set_property\",\"mute\",$val]}" >/dev/null || return 1
    mkdir -p "$CACHE"; printf '%s' "$on" > "$(f_audio "$mon")"
}

# ── Rotación propia ───────────────────────────────────────────────────────────────────────────
# El `-n <s>` de mpvpaper es un temporizador INTERNO suyo, no una propiedad de mpv: no se puede
# ni parar ni adelantar por IPC. Así que la rotación la lleva este bucle y a mpvpaper se le deja
# un `-n` enorme (ver start()). El bucle no guarda nada en memoria: lee el reloj de f_ultimo, de
# modo que el botón de saltar reinicia la cuenta sin tener que hablar con él.
rotador() {
    local mon="$1" ahora ultimo
    mkdir -p "$CACHE"; printf '%s' "$$" > "$(f_rotadorpid "$mon")"
    while :; do
        sleep "$TICK"
        is_running "$mon" || break          # red de seguridad: el fondo murió sin pasar por stop()
        if ! rotacion_activa "$mon"; then
            marcar_ultimo "$mon"            # con la rotación off la cuenta no avanza
            continue
        fi
        ahora=$(date +%s)
        ultimo="$(cat "$(f_ultimo "$mon")" 2>/dev/null)"
        [[ "$ultimo" =~ ^[0-9]+$ ]] || { marcar_ultimo "$mon"; continue; }
        (( ahora - ultimo >= INTERVAL )) && siguiente_video "$mon"
    done
    rm -f "$(f_rotadorpid "$mon")"
}

# Se comprueba el cmdline antes de matar: el PID del fichero puede haberse reciclado.
parar_rotador() {
    local pid f args; f="$(f_rotadorpid "$1")"
    pid="$(cat "$f" 2>/dev/null)"
    rm -f "$f"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 0
    mapfile -d '' -t args < "/proc/$pid/cmdline" 2>/dev/null || return 0
    [[ " ${args[*]} " == *" __rotador "* ]] && kill "$pid" 2>/dev/null
    return 0
}

start() {
    local mon="$1" sock
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
    sock="$(socket_de_monitor "$mon")"
    parar_rotador "$mon"
    rm -f "$sock" "$(f_audio "$mon")"
    # setsid -f: mpvpaper sobrevive al cierre del shell del on-click.
    # -n 86400: NO es la rotación (esa la lleva rotador()); es que ese flag es también el camino
    # por el que mpvpaper convierte la CARPETA en una playlist, así que se conserva con un valor
    # tan grande que su temporizador interno nunca estorba.
    # Arranca en mute (no en `no-audio`) para poder darle sonido luego sin relanzarlo.
    # VAAPI en la iGPU (no despierta la NVIDIA) + auto-pause (-p) cuando una ventana lo tapa.
    setsid -f mpvpaper -n 86400 \
        -o "mute=yes --volume=100 --input-ipc-server=$sock --hwdec=auto --loop-file=inf --loop-playlist=inf --shuffle" \
        -p "$mon" "$FOLDER" >/dev/null 2>&1
    # Esperar a que aparezca para que el refresco del icono refleje el estado real.
    for _ in $(seq 15); do is_running "$mon" && break; sleep 0.1; done
    is_running "$mon" || return 1
    marcar_ultimo "$mon"
    # El rotador necesita el socket, que mpv crea un pelín después de arrancar.
    for _ in $(seq 30); do [ -S "$sock" ] && break; sleep 0.1; done
    setsid -f "$0" __rotador "$mon" >/dev/null 2>&1
}

stop() {
    local mon="$1" pid
    parar_rotador "$mon"
    rm -f "$(f_audio "$mon")"
    pid="$(pid_en_monitor "$mon")" || { rm -f "$(socket_de_monitor "$mon")"; return 0; }
    kill "$pid" 2>/dev/null || true
    # Esperar a que muera (evita que waybar relea "ON" mientras aún cierra).
    for _ in $(seq 15); do is_running "$mon" || break; sleep 0.1; done
    rm -f "$(socket_de_monitor "$mon")"
}

# ── Salida para waybar ────────────────────────────────────────────────────────────────────────
# Texto vacío → waybar oculta el módulo entero, no deja un hueco. Es lo que se usa tanto para la
# ranura sin pantalla como para los hijos del desplegable con el fondo apagado.
json_oculto() { printf '{"text":"","tooltip":"","class":"oculto"}\n'; }

json_estado() {  # <glifo> <tooltip> <activo 0|1>
    local clase=inactive
    [ "$3" = "1" ] && clase=active
    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$1" "$2" "$clase"
}

cada_cuanto() {
    if (( INTERVAL >= 60 && INTERVAL % 60 == 0 )); then printf '%d min' $(( INTERVAL / 60 ))
    else printf '%d s' "$INTERVAL"; fi
}

# El rotador se invoca a sí mismo por el script y recibe el MONITOR, no la ranura (una ranura
# puede pasar a apuntar a otra pantalla si se desconecta un monitor; el bucle no debe moverse).
if [ "${1:-}" = "__rotador" ]; then rotador "$2"; exit 0; fi

RANURA="${2:-1}"
MONITOR="$(monitor_de_ranura "$RANURA")"
case "$RANURA" in 2) SUPER="²" ;; *) SUPER="¹" ;; esac

# Los hijos del desplegable solo existen si ese fondo está encendido Y tiene socket (un mpvpaper
# lanzado antes de esta versión corre sin él: se oculta hasta que se reinicie el fondo).
hijos_visibles() {
    [ -n "$MONITOR" ] && is_running "$MONITOR" && [ -S "$(socket_de_monitor "$MONITOR")" ]
}

# Una sola señal para TODOS los módulos: cada clic refresca los dos anclas y sus seis hijos (y de
# paso reevalúa si la ranura 2 debe verse).
refrescar() { pkill -RTMIN+"$SIGNAL" waybar 2>/dev/null || true; }

case "${1:-status}" in
    toggle)
        if is_running "$MONITOR"; then stop "$MONITOR"; else start "$MONITOR" || true; fi
        refrescar
        ;;
    audio-toggle)
        if hijos_visibles; then
            if audio_activo "$MONITOR"; then
                audio_set "$MONITOR" 0
            else
                # Exclusivo: solo suena una pantalla a la vez, o se solaparían dos bandas sonoras.
                for r in 1 2; do
                    otro="$(monitor_de_ranura "$r")"
                    [ -n "$otro" ] && [ "$otro" != "$MONITOR" ] && audio_activo "$otro" \
                        && audio_set "$otro" 0
                done
                audio_set "$MONITOR" 1 ||
                    notify-send -a "Live wallpaper" "No se pudo activar el sonido en $MONITOR" 2>/dev/null
            fi
        fi
        refrescar
        ;;
    rotacion-toggle)
        if hijos_visibles; then
            mkdir -p "$CACHE"
            if rotacion_activa "$MONITOR"; then
                printf '0' > "$(f_rotacion "$MONITOR")"
            else
                rm -f "$(f_rotacion "$MONITOR")"
                marcar_ultimo "$MONITOR"   # que no salte un vídeo justo al reactivarla
            fi
        fi
        refrescar
        ;;
    saltar)
        if hijos_visibles; then
            siguiente_video "$MONITOR" ||
                notify-send -a "Live wallpaper" "No se pudo cambiar de vídeo en $MONITOR" 2>/dev/null
        fi
        refrescar
        ;;
    audio-status)
        if ! hijos_visibles; then json_oculto
        elif audio_activo "$MONITOR"; then
            json_estado "󰕾" "Sonido del vídeo ($MONITOR): ON — clic para silenciar" 1
        else
            json_estado "󰕾" "Sonido del vídeo ($MONITOR): OFF — clic para activarlo" 0
        fi
        ;;
    rotacion-status)
        if ! hijos_visibles; then json_oculto
        elif rotacion_activa "$MONITOR"; then
            json_estado "󰑖" "Cambio de vídeo cada $(cada_cuanto) ($MONITOR): ON — clic para fijar el actual" 1
        else
            json_estado "󰑖" "Cambio de vídeo ($MONITOR): OFF, vídeo fijo — clic para reanudarlo" 0
        fi
        ;;
    saltar-status)
        # Es una ACCIÓN, no un interruptor: no tiene estado que pintar, por eso clase propia.
        if ! hijos_visibles; then json_oculto
        else printf '{"text":"󰒭","tooltip":"Siguiente vídeo ya (%s)","class":"accion"}\n' "$MONITOR"; fi
        ;;
    status|*)
        if [ -z "$MONITOR" ]; then
            # Sin pantalla para esta ranura (portátil, o segundo monitor desconectado).
            json_oculto
        elif is_running "$MONITOR"; then
            json_estado "󰕧$SUPER" "Fondo de vídeo ($MONITOR): ON — clic para apagar" 1
        else
            json_estado "󰕧$SUPER" "Fondo de vídeo ($MONITOR): OFF — clic para encender" 0
        fi
        ;;
esac
