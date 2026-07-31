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

set -uo pipefail   # sin -e a propósito: ningún fallo suelto debe abortar el rescate de la pantalla

LOG="$HOME/.cache/ml4w-juanjo/despertar-pantallas.log"
ESPERA_SESION=15   # s máximos esperando a que logind reactive la sesión
INTENTOS=3

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

log "── despertar (sesión ${XDG_SESSION_ID:-?}) ──"

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
todas_encendidas && { log "OK tras reload"; exit 0; }

log "FALLO: pantallas sin recuperar. Revisar $HOME/.cache/ml4w-juanjo/ y el log de Hyprland."
exit 1
