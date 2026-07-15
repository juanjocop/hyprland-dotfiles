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

# 2. Asegurar permiso de ejecución de nuestros scripts del theme en destino.
chmod +x "$DEST/waybar/themes/$THEME/scripts/"*.sh

# 3. Fijar nuestro theme como activo (formato /CARPETA;/CARPETA/VARIACIÓN).
echo "/$THEME;/$THEME/default" > "$DEST/ml4w/settings/waybar-theme.sh"

# 4. Relanzar waybar leyendo el theme activo (launch.sh) — no vale SIGUSR2 porque cambiamos
#    de theme, no solo de contenido.
"$DEST/waybar/launch.sh" >/dev/null 2>&1 &

# 5. Luz nocturna (hyprsunset): desplegar config con horario y arrancar el daemon vía systemd
#    (unit empaquetada, persistente en cada login). No es archivo de ML4W → cero deriva.
mkdir -p "$DEST/hypr"
cp -f "$ROOT/overlay/hypr/hyprsunset.conf" "$DEST/hypr/hyprsunset.conf"
systemctl --user enable hyprsunset.service >/dev/null 2>&1 || true
pkill -x hyprsunset 2>/dev/null || true          # matar instancia manual/antigua si la hay
systemctl --user restart hyprsunset.service       # recargar con el nuevo config

# 6. Fastfetch: logo rotativo. Desplegar nuestro config (fichero de ML4W → symlink al árbol,
#    se re-aplica tras cada update) y sincronizar las imágenes a un namespace propio fuera de
#    ML4W (~/.config/ml4w-juanjo/), que el updater nunca poda. fastfetch elige un PNG al azar
#    en cada arranque gracias al glob de logo.source.
cp -f "$ROOT/overlay/fastfetch/config.jsonc" "$DEST/fastfetch/config.jsonc"
mkdir -p "$DEST/ml4w-juanjo/fastfetch-logos"
rsync -a --delete "$ROOT/overlay/fastfetch/logos/" "$DEST/ml4w-juanjo/fastfetch-logos/"

# 7. Variante(s) de decoración propia(s). Fichero(s) nuevo(s) que ML4W no trae → se re-siembran
#    tras cada update. Aparecen solos en Appearance por su cabecera `-- name:`. El usuario las
#    selecciona desde la GUI (no forzamos conf/decoration.lua para no pelear con el picker).
mkdir -p "$DEST/hypr/conf/decorations"
cp -f "$ROOT"/overlay/hypr/conf/decorations/*.lua "$DEST/hypr/conf/decorations/"

echo "✔  Overlay aplicado (theme $THEME activo; hyprsunset con horario 21:00→07:00; fastfetch con logo aleatorio; variante decoración 'Juanjo' disponible en Appearance)."
