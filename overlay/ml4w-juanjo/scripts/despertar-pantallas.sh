#!/usr/bin/env bash
# despertar-pantallas.sh — reenciende las pantallas de forma fiable al reanudar.
#
# Sustituye al disparo único y a ciegas que ML4W trae de serie en hypridle.conf:
#     after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
# En el sobremesa eso dejaba la pantalla en NEGRO tras suspender (issue #1). Ojo: NO es el crash
# de aquamarine 0.13.0 (#337, arreglado en 0.14.0). Es otro fallo: Hyprland sigue vivo y los
# monitores detectados, pero los outputs se quedan deshabilitados y nadie los reenciende. En el
# log de la sesión que falló hay una única transición en 2199 líneas:
#     drm: Connector DP-1 enabledState changed true -> false
# y ni un solo `false -> true`. Dos causas posibles, las dos cubiertas aquí:
#
#   (a) CARRERA. `after_sleep_cmd` salta con PrepareForSleep(false), o sea en el instante de
#       despertar, cuando la sesión de logind todavía NO se ha reactivado. aquamarine contesta
#       `Session inactive` (hay cuatro seguidos justo antes del `Enabling seat`) y el encendido
#       se pierde. Nadie lo reintenta.  → aquí ESPERAMOS a que la sesión esté activa.
#
#   (b) DESINCRONIZACIÓN DE ESTADO. Estos monitores tiran el enlace DisplayPort a los ~6 s de
#       apagarse (verificado con prueba controlada el 2026-07-31: DP-1 desaparece de
#       `hyprctl monitors` y reaparece solo). Al reconectar se recrean como monitor NUEVO, con
#       dpms=true, mientras el conector sigue `enabledState=false` por debajo. Entonces "enable"
#       es un no-op: Hyprland cree que ya están encendidas.  → aquí CICLAMOS (apagar + encender)
#       en vez de solo encender, que fuerza una transición real.
#
# Por eso el ciclo es incondicional: en el caso (b) `hyprctl monitors` MIENTE, así que consultar
# el estado y decidir "ya están bien, no toco nada" sería justo el error que causa el bug.
#
# Que enable funciona con la sesión activa está verificado: en la prueba del 31-07 recuperó las
# dos pantallas en menos de 2 s. Lo que fallaba era CUÁNDO y CUÁNTAS VECES se llamaba.
#
# hypridle nos llama DOS veces al reanudar (`after_sleep_cmd` y, unos segundos después, el
# `on-resume` del listener de 11 min al mover el ratón). Si la primera funcionó, la segunda solo
# aporta un parpadeo de más, así que se omite durante $VENTANA segundos. La marca se escribe solo
# cuando el encendido SALE BIEN: si falla, la segunda llamada sigue siendo una segunda oportunidad.

set -uo pipefail   # sin -e a propósito: ningún fallo suelto debe abortar el rescate de la pantalla

LOG="$HOME/.cache/ml4w-juanjo/despertar-pantallas.log"
SELLO="$HOME/.cache/ml4w-juanjo/despertar-pantallas.stamp"
PID_VIGILANTE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ml4w-juanjo/inactividad/vigilante.pid"
ESPERA_SESION=15   # s máximos esperando a que logind reactive la sesión
INTENTOS=3
VENTANA=30         # s durante los que NO se repite un encendido que ya salió bien

mkdir -p "$(dirname "$LOG")"
# Recorte para que no crezca sin fin (esto se ejecuta en cada reanudación).
if [[ -f "$LOG" ]] && (( $(wc -l < "$LOG") > 500 )); then
    tail -n 200 "$LOG" > "$LOG.tmp" && mv -f "$LOG.tmp" "$LOG"
fi
log() { printf '%s  %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

dpms() { hyprctl dispatch "hl.dsp.dpms({ action = \"$1\" })" >/dev/null 2>&1; }

# Resumen legible del estado, solo para el log. Sin jq: no está garantizado en las dos máquinas.
estado() {
    hyprctl monitors 2>/dev/null \
        | awk '/^Monitor /{n=$2} /dpmsStatus:/{printf "%s=%s ", n, $2} END{print ""}'
}

# ¿Todos los monitores encendidos? Devuelve falso también si no hay ninguno (sesión sin salida).
todas_encendidas() {
    local out n on
    out=$(hyprctl monitors 2>/dev/null) || return 1
    n=$(grep -c '^Monitor ' <<< "$out")
    on=$(grep -c 'dpmsStatus: 1' <<< "$out")
    [[ "$n" -gt 0 && "$n" -eq "$on" ]]
}

sesion_activa() {
    local sid="${XDG_SESSION_ID:-}"
    if [[ -z "$sid" ]]; then
        sid=$(loginctl list-sessions --no-legend 2>/dev/null \
              | awk -v u="$USER" '$3 == u { print $1; exit }')
    fi
    # Sin dato fiable no bloqueamos: mejor intentar el encendido que no hacer nada.
    [[ -n "$sid" ]] || return 0
    [[ "$(loginctl show-session "$sid" -p Active --value 2>/dev/null)" == "yes" ]]
}

# Marca de "encendido que salió bien". Se escribe SOLO al terminar con éxito, nunca al empezar:
# así un intento fallido no bloquea al siguiente, que es justo la segunda oportunidad que da
# `on-resume` cuando el usuario toca el ratón.
exito() { : > "$SELLO"; }
reciente() {
    [[ -f "$SELLO" ]] || return 1
    local edad=$(( $(date +%s) - $(stat -c %Y "$SELLO" 2>/dev/null || echo 0) ))
    (( edad >= 0 && edad < VENTANA ))
}

log "── despertar (sesión ${XDG_SESSION_ID:-?}) ──"

# 0.a LO PRIMERO: matar al vigilante del apagado de idle-guard.sh, si lo hay. Mientras las
#     pantallas estén apagadas por inactividad, ese bucle reaplica el apagado cada vez que un
#     monitor se enciende solo (la DP-1 lo hace: tira el enlace DP y Hyprland la vuelve a
#     modesetear). Aquí venimos a ENCENDER, y al volver de una suspensión la marca de apagado
#     sigue puesta — un vigilante vivo desharía nuestro encendido y dejaría el fondo negro de la
#     issue #1. Quien manda es este script: primero se le para, luego se enciende.
if [[ -f "$PID_VIGILANTE" ]]; then
    vig_pid=$(<"$PID_VIGILANTE")
    rm -f "$PID_VIGILANTE"
    if [[ -n "$vig_pid" ]] && kill "$vig_pid" 2>/dev/null; then
        log "vigilante del apagado (pid $vig_pid) parado antes de encender"
    fi
fi

# 0. Al reanudar se nos llama dos veces: `after_sleep_cmd` al despertar el sistema y, unos
#    segundos después, el `on-resume` del listener de 11 min en cuanto el usuario mueve el ratón.
#    Si la primera ya dejó las pantallas encendidas, la segunda solo aporta un parpadeo de más.
if reciente; then
    log "omitido: ya hubo un encendido correcto hace menos de ${VENTANA}s"
    exit 0
fi

# 1. Esperar a que la sesión vuelva a estar activa (caso (a)).
esperado=0
while (( esperado < ESPERA_SESION )); do
    sesion_activa && break
    sleep 1
    (( esperado++ ))
done
if sesion_activa; then
    log "sesión activa tras ${esperado}s; estado: $(estado)"
else
    log "AVISO: la sesión sigue inactiva tras ${ESPERA_SESION}s; lo intento igualmente"
fi

# 2. Ciclar DPMS hasta que las dos pantallas estén encendidas (caso (b)).
for (( i = 1; i <= INTENTOS; i++ )); do
    dpms disable
    sleep 1
    dpms enable
    sleep 2
    log "ciclo $i → $(estado)"
    if todas_encendidas; then
        log "OK en el ciclo $i"
        exito
        exit 0
    fi
done

# 3. Último cartucho: recargar la config, que reaplica las reglas de monitor.
log "los $INTENTOS ciclos no bastaron; probando hyprctl reload"
hyprctl reload >/dev/null 2>&1
sleep 2
dpms enable
sleep 1
log "tras reload → $(estado)"
todas_encendidas && { log "OK tras reload"; exito; exit 0; }

log "FALLO: pantallas sin recuperar. Revisar $HOME/.cache/ml4w-juanjo/ y el log de Hyprland."
exit 1
