#!/usr/bin/env bash
# cava-enlazar-audio.sh — hace que cava reaccione a CUALQUIER sonido del equipo,
# no solo al de una salida.
#
# EL PROBLEMA que resuelve
# -----------------------
# cava lee de UNA sola fuente. Con `source = auto` (nuestras dos configs) su backend de pulse
# resuelve el monitor del sink PREDETERMINADO **una vez, al arrancar**, y ahí se queda. O sea:
#
#   · si el sonido sale por un sink que NO es el predeterminado → barras planas;
#   · si cambias de salida con cava ya abierto        → barras planas.
#
# Caso real que lo destapó (2026-08-15): predeterminado = auriculares HyperX, pero el audio del
# fondo de vídeo iba al HDMI del ASUS. cava seguía enganchado al monitor de los HyperX, que
# estaba IDLE, y no se movía una barra. No era un fallo de cava ni de la config: es su diseño.
#
# LA SOLUCIÓN
# -----------
# PipeWire permite enlazar VARIAS salidas al mismo puerto de entrada, y las suma. Así que en vez
# de pelearnos con qué fuente elige cava, le enchufamos a mano el monitor de todos los sinks:
#
#   alsa_output.<loquesea>:monitor_FL ──┐
#   alsa_output.<otro>:monitor_FL    ──┴──> cava:input_FL
#
# Por qué un bucle y no un enlace único al arrancar — hay tres cosas que rompen los enlaces y
# todas pasan en uso normal:
#   1. aparecen sinks nuevos (conectas el bluetooth, cambias el perfil de la tarjeta HDMI);
#   2. al cambiar el sink predeterminado, pulse-server MUEVE el stream de cava, y al moverlo
#      deshace los enlaces que había — incluidos los nuestros;
#   3. un sink que desaparece se lleva su enlace.
# El bucle los rehace en <=2 s en los tres casos. `pw-link` sobre un enlace que ya existe falla
# con "File exists" y no duplica nada, así que repetir es inofensivo y no hace falta comparar.
#
# Muere solo cuando muere cava (no hay que pararlo desde cava-toggle.sh).
#
# Se despliega a ~/.config/ml4w-juanjo/scripts/ (namespace propio, fuera del árbol de ML4W).

# Sin `-e`: los pw-link fallidos ("File exists", sink que se acaba de ir) son lo NORMAL aquí.
set -uo pipefail

INTERVALO=2      # segundos entre repasos
ESPERA_MAX=15    # segundos esperando a que cava levante su nodo antes de rendirse

# Instancia única, por lock y NO por `pkill -f cava-enlazar-audio.sh` desde el toggle.
# Un pkill por patrón acierta a cualquier proceso que lleve ese texto en su línea de comandos
# —incluida la shell que lo invoca desde un script o un terminal—, así que se suicida. Con el
# lock, el toggle lanza sin pensar: si ya hay uno vivo, el nuevo se va solo por aquí.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/cava-enlazar-audio.lock"
flock -n 9 || exit 0

# ¿Tiene cava sus puertos de entrada en el grafo? Es la señal de "cava vivo y conectado":
# el proceso puede existir un instante antes de que PipeWire le cree el nodo.
cava_vivo() { pw-link -i 2>/dev/null | grep -q '^cava:input_'; }

# Un repaso: enlaza el monitor de cada sink real a la entrada de cava.
enlazar() {
    local sinks puertos puerto nodo canal destinos destino s es_sink

    # Los sinks REALES, preguntados a pulse. No vale con filtrar `pw-link -o | grep monitor`,
    # porque en esa lista también salen:
    #   · `cava:monitor_*`   → el propio cava (es un stream de captura y expone monitor).
    #     Enlazar eso a su entrada sería un BUCLE de realimentación.
    #   · los medidores de picos de pavucontrol, y cualquier otro stream de captura abierto.
    mapfile -t sinks < <(pactl list sinks short 2>/dev/null | awk '{print $2}')
    [[ ${#sinks[@]} -eq 0 ]] && return 0

    mapfile -t puertos < <(pw-link -o 2>/dev/null)

    for puerto in "${puertos[@]}"; do
        nodo="${puerto%%:*}"
        canal="${puerto#*:}"
        [[ "$canal" == monitor_* ]] || continue

        # ¿el nodo es uno de los sinks? (comparación exacta: los nombres llevan puntos y guiones
        # que en un grep serían metacaracteres)
        es_sink=0
        for s in "${sinks[@]}"; do
            [[ "$s" == "$nodo" ]] && { es_sink=1; break; }
        done
        ((es_sink)) || continue

        # Los sinks mono existen (un manos libres bluetooth): su única señal va a los dos lados.
        case "${canal#monitor_}" in
            FL)   destinos="cava:input_FL" ;;
            FR)   destinos="cava:input_FR" ;;
            MONO) destinos="cava:input_FL cava:input_FR" ;;
            *)    continue ;;
        esac

        for destino in $destinos; do
            pw-link "$puerto" "$destino" 2>/dev/null || true
        done
    done
}

# Esperar a que cava levante. Si en ESPERA_MAX no aparece, es que el toggle falló: salir sin ruido.
esperado=0
until cava_vivo; do
    ((esperado++ >= ESPERA_MAX)) && exit 0
    sleep 1
done

while cava_vivo; do
    enlazar
    sleep "$INTERVALO"
done
