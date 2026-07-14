#!/usr/bin/env bash
# aplicar.sh — despliega nuestro theme propio ml4w-glass-juanjo sobre el árbol de ML4W,
# lo fija como theme activo y relanza waybar. Ejecutar tras cada update de ML4W (por si el
# updater podó carpetas desconocidas) o tras editar el overlay. NUNCA se edita el vivo a mano.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.config"
THEME="ml4w-glass-juanjo"

# 1. Copiar nuestro theme (carpeta autocontenida) al árbol de waybar.
#    ~/.config/waybar es un symlink al árbol de ML4W → rsync escribe ahí (es lo que queremos).
rsync -a --delete "$ROOT/overlay/waybar/themes/$THEME/" \
                  "$DEST/waybar/themes/$THEME/"

# 2. Asegurar permiso de ejecución del script de GPU en destino.
chmod +x "$DEST/waybar/themes/$THEME/scripts/gputemp.sh"

# 3. Fijar nuestro theme como activo (formato /CARPETA;/CARPETA/VARIACIÓN).
echo "/$THEME;/$THEME/default" > "$DEST/ml4w/settings/waybar-theme.sh"

# 4. Relanzar waybar leyendo el theme activo (launch.sh) — no vale SIGUSR2 porque cambiamos
#    de theme, no solo de contenido.
"$DEST/waybar/launch.sh" >/dev/null 2>&1 &

echo "✔  Overlay aplicado (theme $THEME activo)."
