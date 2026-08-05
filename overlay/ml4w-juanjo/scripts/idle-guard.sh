#!/usr/bin/env bash
# idle-guard.sh — guardián de la inactividad: decide, en el momento del disparo, si una acción de
# hypridle (bloquear, apagar pantallas, suspender) se ejecuta o se ignora.
#
# POR QUÉ EXISTE. Dejar algo trabajando solo (una IA en una terminal, una compilación larga) choca
# con hypridle: a los 30 min suspende, y una suspensión CONGELA todos los procesos. El bloqueo y el
# apagado de pantallas, en cambio, no detienen nada — solo molestan cuando quieres vigilar el
# progreso de un vistazo. Son tres cosas distintas y hacen falta tres interruptores distintos.
#
# POR QUÉ ASÍ Y NO DE OTRA FORMA (verificado en la máquina, no re-derivar):
#
#   - hypridle 0.1.8 NO tiene IPC. No hay socket de control: no se puede activar/desactivar un
#     listener en caliente. `ignore_inhibit` existe, pero es estático y por listener.
#   - Los inhibidores estándar son GLOBALES: `systemd-inhibit --what=idle` frena todos los
#     listeners a la vez. Es exactamente la granularidad todo-o-nada que queremos evitar (y es lo
#     que ya hace el botón `custom/hypridle` de ML4W, que además mata el daemon entero y con él el
#     `after_sleep_cmd` que arregla la pantalla en negro — issue #1).
#   - Reescribir el hypridle.conf vivo comentando listeners rompería la igualdad byte a byte
#     overlay ↔ vivo que comprueba check.sh, y relanzar hypridle REINICIA el contador de inactividad.
#
# Como el overlay ya es dueño de hypridle.conf, la vía limpia es la INDIRECCIÓN: los `on-timeout`
# llaman aquí, y aquí se mira una bandera y se decide. Config estático, daemon intacto.
#
# EL ESTADO VIVE EN tmpfs ($XDG_RUNTIME_DIR), a propósito: la inhibición se limpia sola al cerrar
# sesión o reiniciar. Nada de ~/.cache — dejarse el equipo sin suspender "para siempre" sin
# recordarlo es justo el fallo que no queremos.
#
# Uso:
#   idle-guard.sh accion   <pantallas-off|pantallas-on|bloquear|suspender>   ← lo llama hypridle
#   idle-guard.sh estado   <pantallas|bloqueo|suspension|maestro>            ← JSON para waybar
#   idle-guard.sh alternar <pantallas|bloqueo|suspension|maestro>            ← on-click de waybar
#   idle-guard.sh vigilante                                                  ← uso interno (ver abajo)

set -uo pipefail   # sin -e a propósito, como despertar-pantallas.sh: ningún fallo suelto debe
                   # abortar una acción de pantalla a medias.

ESTADO_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ml4w-juanjo/inactividad"
MARCA_APAGADAS="$ESTADO_DIR/pantallas-apagadas"   # ver la nota del parpadeo, más abajo
PID_VIGILANTE="$ESTADO_DIR/vigilante.pid"         # ver el bloque del vigilante, más abajo
LOG="$HOME/.cache/ml4w-juanjo/idle-guard.log"
DESPERTAR="$HOME/.config/ml4w-juanjo/scripts/despertar-pantallas.sh"
SENAL=10           # = "signal" de los cuatro módulos de waybar (1, 8 y 9 ya están cogidas)

VIG_INTERVALO=2    # s entre sondeos del vigilante
VIG_MAX_REAP=3     # veces que reaplica el apagado antes de rendirse (evita el ping-pong infinito)
VIG_MAX_HORAS=8    # tope duro por si la marca se quedara huérfana

ICONO_MAESTRO="󰅶"
ICONO_PANTALLAS="󰍹"
ICONO_BLOQUEO="󰌾"
ICONO_SUSPENSION="󰤄"

mkdir -p "$ESTADO_DIR" "$(dirname "$LOG")"

# Recorte para que el log no crezca sin fin (se escribe en cada disparo de hypridle).
if [[ -f "$LOG" ]] && (( $(wc -l < "$LOG") > 500 )); then
    tail -n 200 "$LOG" > "$LOG.tmp" && mv -f "$LOG.tmp" "$LOG"
fi
log() { printf '%s  %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

inhibido() { [[ -f "$ESTADO_DIR/$1" ]]; }
inhibir() { : > "$ESTADO_DIR/$1"; }
permitir() { rm -f "$ESTADO_DIR/$1"; }
alguno_inhibido() { inhibido pantallas || inhibido bloqueo || inhibido suspension; }
todos_inhibidos() { inhibido pantallas && inhibido bloqueo && inhibido suspension; }

refrescar() { pkill -RTMIN+"$SENAL" waybar 2>/dev/null || true; }

# JSON de una línea para waybar, sin jq (no está garantizado en las dos máquinas).
emitir() { printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$1" "$2" "$3"; }

# ── El vigilante del apagado ─────────────────────────────────────────────────────────────────
# POR QUÉ EXISTE. `dpms disable` apaga las dos pantallas, pero la DP-1 (KTC H27E6, la de 240 Hz)
# SE VUELVE A ENCENDER SOLA a los pocos segundos y se queda encendida toda la noche. No es cosa
# nuestra: es el mismo tirón de enlace DisplayPort ya documentado en despertar-pantallas.sh, visto
# desde el otro lado. En el log de aquamarine, después de apagar:
#     drm: Connector DP-1 disconnected → Disabling output DP-1 → enabledState true -> false
#     drm: Connector DP-1 connected → Connecting connector DP-1, CRTC ID 200
#     drm: Modesetting DP-1 with 2560x1440@240.00Hz
# El monitor tira el enlace al quedarse sin señal; al reasomar, Hyprland lo trata como un monitor
# NUEVO y le hace modeset — y un modeset enciende el panel. Hyprland no recuerda que estábamos en
# modo "pantallas apagadas por inactividad", así que nadie deshace ese encendido.
#
# Efecto colateral que también arregla esto: al volver, despertar-pantallas.sh CICLA el dpms
# (apagar + encender, a propósito — ver su cabecera), así que con la DP-1 ya encendida se veía
# "la 1 se apaga y luego se encienden las dos". Con las dos realmente apagadas, la mitad
# `disable` del ciclo deja de notarse.
#
# CÓMO. Mientras exista la marca de apagado, un bucle desatado sondea `hyprctl monitors` y
# reaplica el apagado si alguna pantalla aparece encendida. Se sondea en vez de escuchar el
# socket2 de Hyprland porque el bucle solo vive durante el apagado y no hace falta ni socat ni
# nc -U (no están garantizados en las dos máquinas).
#
# TRES FRENOS, porque un vigilante que se equivoca deja el equipo a oscuras:
#   1. $VIG_MAX_REAP. Si el monitor vuelve a tirar el enlace cada vez que lo apagamos, esto sería
#      un ping-pong de parpadeos. Tras N reaplicaciones se rinde y lo deja encendido — o sea, el
#      comportamiento de antes de este parche, ni mejor ni peor, y con el motivo en el log.
#   2. Muere solo. Si desaparece la marca (volviste al equipo), si `hyprctl` no contesta (Hyprland
#      se ha reiniciado: hereda HYPRLAND_INSTANCE_SIGNATURE, así que solo puede tocar SU sesión) o
#      si pasan $VIG_MAX_HORAS.
#   3. despertar-pantallas.sh lo mata NADA MÁS EMPEZAR. Es crítico para la vuelta de una
#      suspensión: ahí las pantallas se encienden por `after_sleep_cmd`, con la marca todavía
#      puesta, y un vigilante vivo las volvería a apagar. Justo el fondo negro de la issue #1.
monitores_encendidos() { awk '/^Monitor /{n=$2} /dpmsStatus: 1/{printf "%s ", n}' <<< "$1"; }

parar_vigilante() {
    local pid
    [[ -f "$PID_VIGILANTE" ]] || return 0
    pid=$(<"$PID_VIGILANTE")
    rm -f "$PID_VIGILANTE"
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null
    return 0
}

# El hijo escribe su propio PID (con `setsid` el $! del padre no es fiable: setsid solo hace fork
# si ya era líder de grupo, y hypridle nos lanza vía `sh -c`, así que lo es).
arrancar_vigilante() {
    parar_vigilante
    setsid "${BASH:-/usr/bin/env bash}" "$0" vigilante </dev/null >/dev/null 2>&1 &
}

vigilante() {
    echo $$ > "$PID_VIGILANTE"
    local reaplicaciones=0 encendidas salida
    local fin=$(( $(date +%s) + VIG_MAX_HORAS * 3600 ))
    while sleep "$VIG_INTERVALO"; do
        [[ -f "$MARCA_APAGADAS" ]] || break            # has vuelto al equipo: ya no pintamos nada
        (( $(date +%s) < fin )) || { log "vigilante: fin por tope de ${VIG_MAX_HORAS} h"; break; }
        salida=$(hyprctl monitors 2>/dev/null) || { log "vigilante: hyprctl no contesta; salgo"; break; }
        grep -q 'dpmsStatus: 1' <<< "$salida" || continue
        encendidas=$(monitores_encendidos "$salida")
        if (( reaplicaciones >= VIG_MAX_REAP )); then
            log "vigilante: ${encendidas}se enciende(n) sola(s) una y otra vez; me rindo tras $VIG_MAX_REAP intentos"
            break
        fi
        (( reaplicaciones++ ))
        log "vigilante: ${encendidas}se ha(n) encendido sola(s); reaplico apagado ($reaplicaciones/$VIG_MAX_REAP)"
        hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })' >/dev/null 2>&1
    done
    # Solo si el fichero sigue siendo nuestro: si nos han relevado, es del vigilante nuevo.
    [[ -f "$PID_VIGILANTE" && "$(<"$PID_VIGILANTE")" == "$$" ]] && rm -f "$PID_VIGILANTE"
    return 0
}

# ── Acciones: las llama hypridle cuando vence un timeout ─────────────────────────────────────
accion() {
    case "$1" in
    bloquear)
        if inhibido bloqueo; then log "omitido: bloqueo de sesión inhibido"; return 0; fi
        loginctl lock-session
        ;;
    pantallas-off)
        if inhibido pantallas; then log "omitido: apagado de pantallas inhibido"; return 0; fi
        hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })' >/dev/null 2>&1
        : > "$MARCA_APAGADAS"
        arrancar_vigilante   # la DP-1 se reenciende sola; ver el bloque del vigilante
        ;;
    pantallas-on)
        parar_vigilante   # lo primero: que no nos apague las pantallas por detrás
        # `brightnessctl -r` es lo que traía el on-resume de ML4W; inofensivo donde no hay
        # backlight (el sobremesa no tiene /sys/class/backlight).
        brightnessctl -r >/dev/null 2>&1 || true
        # OJO, ESTA MARCA NO ES OPCIONAL: el on-resume del listener de 11 min salta al mover el
        # ratón AUNQUE las pantallas nunca se hayan apagado, y despertar-pantallas.sh cicla el
        # DPMS de forma incondicional (apagar + encender, a propósito — ver su cabecera). Sin la
        # marca, inhibir el apagado provocaría un parpadeo cada vez que vuelves al equipo. El
        # $SELLO de aquel script no cubre esto: deduplica dos encendidos seguidos, no un
        # encendido sin apagado previo.
        if [[ -f "$MARCA_APAGADAS" ]]; then
            rm -f "$MARCA_APAGADAS"
            "$DESPERTAR"
        else
            log "reanudación sin apagado previo: no se cicla el DPMS (evita el parpadeo)"
        fi
        ;;
    suspender)
        if inhibido suspension; then log "omitido: suspensión inhibida"; return 0; fi
        systemctl suspend
        ;;
    *)
        echo "acción desconocida: $1" >&2; return 2
        ;;
    esac
}

# ── Estado: JSON para waybar ─────────────────────────────────────────────────────────────────
# El texto dice siempre qué PASA, no qué bandera hay puesta: "DESACTIVADO (no se apagarán)" se
# entiende de un vistazo; "inhibición activa" se presta a leerlo al revés.
#
# LOS HIJOS siguen la misma convención que el resto de botones de la barra (fondo de vídeo, luz
# nocturna): `active` = esa función funciona (coloreada), `inactive` = la has desactivado
# (atenuada). Encender el interruptor es "que sí se apague/bloquee/suspenda".
#
# EL ANCLA VA AL REVÉS, a propósito: su icono es un CAFÉ, y un café no representa "el bloqueo
# funciona" sino CAFEÍNA. Café coloreado = estoy manteniendo el equipo despierto (los tres
# desactivados); café atenuado = todo normal; `parcial` = algo de cafeína. La incoherencia con los
# hijos la paga el icono, que se lee solo — y además destaca justo el estado que conviene no
# olvidarse puesto. Los tooltips lo dicen con todas las letras ("Café ON/OFF") por si acaso.
estado() {
    case "$1" in
    pantallas)
        if inhibido pantallas; then
            emitir "$ICONO_PANTALLAS" "Apagado de pantallas: DESACTIVADO (no se apagarán solas) — clic para reactivarlo" "inactive"
        else
            emitir "$ICONO_PANTALLAS" "Apagado de pantallas: activo (a los 11 min) — clic para desactivarlo" "active"
        fi
        ;;
    bloqueo)
        if inhibido bloqueo; then
            emitir "$ICONO_BLOQUEO" "Bloqueo automático: DESACTIVADO (la sesión no se bloqueará sola) — clic para reactivarlo" "inactive"
        else
            emitir "$ICONO_BLOQUEO" "Bloqueo automático: activo (a los 10 min) — clic para desactivarlo" "active"
        fi
        ;;
    suspension)
        if inhibido suspension; then
            emitir "$ICONO_SUSPENSION" "Suspensión: DESACTIVADA (el equipo seguirá trabajando) — clic para reactivarla" "inactive"
        else
            emitir "$ICONO_SUSPENSION" "Suspensión: activa (a los 30 min) — clic para desactivarla" "active"
        fi
        ;;
    maestro)
        local activas=() clase texto
        inhibido pantallas && activas+=("pantallas")
        inhibido bloqueo && activas+=("bloqueo")
        inhibido suspension && activas+=("suspensión")
        # OJO: el ancla va al REVÉS que sus hijos, y es a propósito (ver la nota de arriba).
        if (( ${#activas[@]} == 0 )); then
            clase="inactive"
            texto="Café OFF — todo normal: bloqueo 10 min, pantallas 11 min, suspensión 30 min\\nClic: café ON (desactivarlo todo para dejar algo trabajando)"
        elif todos_inhibidos; then
            clase="active"
            texto="Café ON — el equipo no se bloqueará, ni apagará pantallas, ni suspenderá\\nClic: volver a activarlo todo"
        else
            clase="parcial"
            texto="Café a medias — desactivado ${activas[*]}\\nClic: café ON (desactivarlo todo)"
        fi
        emitir "$ICONO_MAESTRO" "$texto" "$clase"
        ;;
    *)
        echo "estado desconocido: $1" >&2; return 2
        ;;
    esac
}

# ── Alternar: on-click de waybar ─────────────────────────────────────────────────────────────
alternar() {
    case "$1" in
    pantallas | bloqueo | suspension)
        if inhibido "$1"; then permitir "$1"; else inhibir "$1"; fi
        ;;
    maestro)
        # Cualquier cosa encendida → apagarlo todo. Nada encendido → modo "trabajo en curso".
        if alguno_inhibido; then
            permitir pantallas; permitir bloqueo; permitir suspension
            log "maestro: inactividad restaurada (bloqueo, pantallas y suspensión activos)"
            notify-send -a "Inactividad" "Todo restaurado" \
                "Bloqueo, apagado de pantallas y suspensión vuelven a funcionar." 2>/dev/null
        else
            inhibir pantallas; inhibir bloqueo; inhibir suspension
            log "maestro: inactividad desactivada por completo"
            notify-send -a "Inactividad" "Modo trabajo en curso" \
                "Ni bloqueo, ni apagado de pantallas, ni suspensión. Se restaura solo al cerrar sesión." 2>/dev/null
        fi
        ;;
    *)
        echo "interruptor desconocido: $1" >&2; return 2
        ;;
    esac
    refrescar
}

case "${1:-}" in
accion)    accion "${2:-}" ;;
estado)    estado "${2:-maestro}" ;;
alternar)  alternar "${2:-maestro}" ;;
vigilante) vigilante ;;   # uso interno: lo relanza arrancar_vigilante con setsid
*)
    echo "uso: $(basename "$0") {accion|estado|alternar} <qué>" >&2
    exit 2
    ;;
esac
