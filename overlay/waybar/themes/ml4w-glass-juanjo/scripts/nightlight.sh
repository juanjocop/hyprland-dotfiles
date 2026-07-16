#!/usr/bin/env bash
# nightlight.sh — luz nocturna (hyprsunset) desde un botón de waybar.
# El horario de hyprsunset.conf manda; este botón es un OVERRIDE manual sobre él vía IPC.
#
# NO matar ni relanzar el daemon: eso era el bug del toggle de ML4W. Hacía `pkill hyprsunset`
# (dejando hyprsunset.service muerto, porque la unit es Restart=on-failure y el pkill sale con
# código 0) y luego `hyprsunset &`, un daemon huérfano fuera de systemd. Y como de día nuestro
# perfil de las 7:00 es `identity`, arrancarlo no calentaba nada: el botón no hacía nada.
#
# Un override por IPC dura hasta la siguiente frontera del horario (07:00 / 21:00), donde el
# hilo schedule() de hyprsunset recupera el mando solo. `reset` lo devuelve al horario ya.
# Uso: status (JSON para waybar) | toggle (cálido ↔ neutro) | schedule (volver al horario).

TEMP="${NIGHTLIGHT_TEMP:-4000}"   # K del override manual (= el del perfil nocturno)
SIGNAL=9                          # = "signal" del módulo (refresco del icono)
ICON="󰖔"

ipc() { hyprctl hyprsunset "$@" 2>/dev/null; }

up() { systemctl --user is-active --quiet hyprsunset.service; }

# Arrancar por systemd (nunca a mano) y esperar a que el socket responda.
ensure_daemon() {
    up && return 0
    systemctl --user start hyprsunset.service 2>/dev/null || return 1
    for _ in $(seq 20); do
        [[ "$(ipc identity get)" =~ ^(true|false)$ ]] && return 0
        sleep 0.1
    done
    return 1
}

# "true" = sin filtro | "false" = filtro activo. Vacío si el daemon no responde.
filtered_off() { ipc identity get; }

refresh() { pkill -RTMIN+"$SIGNAL" waybar 2>/dev/null || true; }

case "${1:-status}" in
    toggle)
        if ! ensure_daemon; then
            notify-send -a "Luz nocturna" "No se pudo arrancar hyprsunset.service" 2>/dev/null
            exit 1
        fi
        # `temperature` pone identity=false por sí solo; no hace falta tocarlo aparte.
        if [[ "$(filtered_off)" == "false" ]]; then
            ipc identity >/dev/null
        else
            ipc temperature "$TEMP" >/dev/null
        fi
        refresh
        ;;
    schedule)
        # Devolver el mando al horario sin esperar a las 07:00 / 21:00.
        ensure_daemon && ipc reset >/dev/null
        refresh
        ;;
    status|*)
        if ! up; then
            printf '{"text":"%s","tooltip":"Luz nocturna: daemon parado — clic para encender","class":"inactive"}\n' "$ICON"
        elif [[ "$(filtered_off)" == "false" ]]; then
            printf '{"text":"%s","tooltip":"Luz nocturna: ON a %sK — clic para quitarla, clic derecho para volver al horario","class":"active"}\n' \
                "$ICON" "$(ipc temperature)"
        else
            printf '{"text":"%s","tooltip":"Luz nocturna: OFF — clic para %sK, clic derecho para volver al horario","class":"inactive"}\n' \
                "$ICON" "$TEMP"
        fi
        ;;
esac
