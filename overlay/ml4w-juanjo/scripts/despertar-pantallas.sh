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
#   (c) VICTORIA FALSA. El tirón de enlace del caso (b) también puede caer JUSTO DESPUÉS de
#       encender: la DP-1 se enciende, tira el enlace y DESAPARECE de la lista de monitores.
#       Con la comprobación de antes ("¿están encendidos todos los que veo?") eso daba
#       verdadero de forma VACÍA — solo quedaba la DP-2, y estaba a 1. Ocurrió el 2026-09-09 a
#       las 11:25: `ciclo 1 → DP-2=1` (compáralo con el `DP-2=1 DP-1=1` de todas las veces que
#       salió bien). El script cantó "OK", escribió el $SELLO y con él anuló la segunda
#       oportunidad del `on-resume`. La DP-1 se quedó negra.  → aquí exigimos una LISTA CONCRETA
#       de monitores ($ESPERADOS) y esperamos a que el ausente reasome; un monitor que falta
#       nunca cuenta como encendido.
#
# Por eso el ciclo es incondicional: en el caso (b) `hyprctl monitors` MIENTE, así que consultar
# el estado y decidir "ya están bien, no toco nada" sería justo el error que causa el bug. Y por
# eso el éxito se mide contra $ESPERADOS y con `hyprctl monitors all`: en el caso (c) la lista
# corta OMITE al monitor problemático, así que preguntar por ella es no preguntar nada.
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
ESPERADOS_F="$HOME/.cache/ml4w-juanjo/despertar-pantallas.monitores"
ESPERA_SESION=15   # s máximos esperando a que logind reactive la sesión
ESPERA_MONITOR=8   # s máximos esperando a que un monitor ausente rehaga su enlace DP
INTENTOS=3
VENTANA=30         # s durante los que NO se repite un encendido que ya salió bien

mkdir -p "$(dirname "$LOG")"
# Recorte para que no crezca sin fin (esto se ejecuta en cada reanudación).
if [[ -f "$LOG" ]] && (( $(wc -l < "$LOG") > 500 )); then
    tail -n 200 "$LOG" > "$LOG.tmp" && mv -f "$LOG.tmp" "$LOG"
fi
log() { printf '%s  %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

dpms() { hyprctl dispatch "hl.dsp.dpms({ action = \"$1\" })" >/dev/null 2>&1; }

# SIEMPRE `hyprctl monitors all`, NUNCA `hyprctl monitors` a secas (no re-derivar): la forma
# corta OCULTA los conectores deshabilitados, que es justo el estado del fallo que este script
# existe para arreglar. Preguntar por la lista corta es preguntarle al problema si hay problema.
monitores() { hyprctl monitors all 2>/dev/null; }

# Nombres de los monitores presentes, uno por línea.
nombres_monitores() { monitores | awk '$1 == "Monitor" { print $2 }'; }

# Resumen legible del estado, solo para el log. Sin jq: no está garantizado en las dos máquinas.
# `dpmsStatus` aparece ANTES que `disabled` dentro de cada bloque, así que hay que acumular y
# volcar al empezar el bloque siguiente. Un `!` delante marca conector deshabilitado, y un
# `AUSENTE` marca un monitor que esperábamos y que ahora mismo no está en la lista.
estado() {
    local salida m linea=""
    salida=$(monitores)
    linea=$(awk '
        $1 == "Monitor"    { if (n != "") printf "%s=%s%s ", n, d, s; n=$2; d=""; s="?"; next }
        $1 == "dpmsStatus:"                   { s=$2 }
        $1 == "disabled:" && $2 == "true"     { d="!" }
        END { if (n != "") printf "%s=%s%s ", n, d, s }' <<< "$salida")
    for m in $ESPERADOS; do
        grep -q "^Monitor $m " <<< "$salida" || linea+="$m=AUSENTE "
    done
    printf '%s' "$linea"
}

# ¿Un monitor concreto está realmente encendido? Las TRES cosas, y las tres importan:
# presente en la lista, conector habilitado y DPMS a 1.
monitor_encendido() {   # $1 = salida de `monitores`, $2 = nombre
    awk -v mon="$2" '
        $1 == "Monitor" && $2 == mon                  { visto=1; dentro=1; ok=1; next }
        $1 == "Monitor"                               { dentro=0 }
        dentro && $1 == "dpmsStatus:" && $2 != 1      { ok=0 }
        dentro && $1 == "disabled:"   && $2 == "true" { ok=0 }
        END { exit !(visto && ok) }' <<< "$1"
}

# ¿Están encendidos TODOS los que esperamos? Ojo con la tentación de preguntar "¿están encendidos
# todos los que veo?": eso es lo que había antes y es una comprobación VACÍA cuando un monitor se
# ha ido. Pasó el 2026-09-09 a las 11:25 — la DP-1 tiró el enlace DP justo después del encendido,
# desapareció de la lista, y el script vio `DP-2=1`, cantó "OK en el ciclo 1", escribió el sello y
# con él se cargó la segunda oportunidad del `on-resume`. La DP-1 se quedó negra.
todas_encendidas() {
    local salida m
    [[ -n "${ESPERADOS// /}" ]] || return 1   # sin lista no hay nada que dar por bueno
    salida=$(monitores) || return 1
    for m in $ESPERADOS; do
        monitor_encendido "$salida" "$m" || return 1
    done
    return 0
}

# ── La lista de monitores exigidos ───────────────────────────────────────────────────────────
# $VISTOS  = los que han aparecido en algún momento de ESTA ejecución.
# $ESPERADOS = $VISTOS + los que había la última vez que esto salió bien ($ESPERADOS_F). Lo
# segundo cubre el caso de que el monitor esté en su ventana de desconexión ya al arrancar
# nosotros: si no lo recordáramos, ni siquiera sabríamos que falta.
# La lista solo CRECE durante los ciclos: un monitor que desaparece sigue siendo exigido, que es
# precisamente lo que faltaba. Lo que ya no está de verdad se poda al final (ver el paso 2.b).
VISTOS=""
ESPERADOS=""

anadir() {   # $1 = lista (por nombre de variable), $2 = elemento
    local -n lista="$1"
    [[ " $lista " == *" $2 "* ]] || lista+=" $2"
}

mirar_monitores() {
    local m
    for m in $(nombres_monitores); do
        anadir VISTOS "$m"
        anadir ESPERADOS "$m"
    done
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
exito() {
    : > "$SELLO"
    # Guardamos los monitores del encendido bueno para poder exigirlos la próxima vez aunque
    # lleguen tarde. Se escribe la lista REAL de ahora, no $ESPERADOS: así una entrada podada
    # en el paso 2.b (un monitor que ya no está) no vuelve a colarse.
    nombres_monitores > "$ESPERADOS_F" 2>/dev/null
}
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
# 1.b Sembrar la lista de monitores exigidos: los de ahora + los del último encendido bueno.
mirar_monitores
if [[ -r "$ESPERADOS_F" ]]; then
    while read -r m; do [[ -n "$m" ]] && anadir ESPERADOS "$m"; done < "$ESPERADOS_F"
fi

if sesion_activa; then
    log "sesión activa tras ${esperado}s; exijo:${ESPERADOS:- (nada)}; estado: $(estado)"
else
    log "AVISO: la sesión sigue inactiva tras ${ESPERA_SESION}s; lo intento igualmente"
fi

# 2. Ciclar DPMS hasta que las dos pantallas estén encendidas (caso (b)).
for (( i = 1; i <= INTENTOS; i++ )); do
    dpms disable
    sleep 1
    dpms enable
    sleep 2
    # Sondeo en vez de una espera fija: tras el encendido la DP-1 puede volver a tirar el
    # enlace y tardar unos segundos en reasomar (al reconectar, Hyprland le hace modeset y eso
    # ya la enciende). Dormir a ciegas y mirar una sola vez es cómo se nos escapó la del 11:25.
    for (( t = 0; t < ESPERA_MONITOR; t++ )); do
        mirar_monitores          # un monitor que reaparece vuelve a la lista de exigidos
        todas_encendidas && break
        sleep 1
    done
    mirar_monitores
    log "ciclo $i → $(estado)"
    if todas_encendidas; then
        log "OK en el ciclo $i"
        exito
        exit 0
    fi
done

# 2.b Podar lo que ya no está. Si lo único que falla es un monitor de la lista GUARDADA que no ha
#     aparecido ni una vez en toda la ejecución, es que ya no está (cable fuera, monitor apagado
#     de verdad). Arrastrarlo significaría fallar y hacer un `hyprctl reload` en cada reanudación,
#     para siempre. Se le retira y la lista se autocorrige sola en el siguiente encendido bueno.
if [[ "$ESPERADOS" != "$VISTOS" ]]; then
    for m in $ESPERADOS; do
        [[ " $VISTOS " == *" $m "* ]] || log "«$m» no ha aparecido en toda la reanudación; lo retiro de la lista"
    done
    ESPERADOS="$VISTOS"
    if todas_encendidas; then
        log "OK una vez retirados los monitores que ya no están"
        exito
        exit 0
    fi
fi

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
