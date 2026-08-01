#!/usr/bin/env bash
# check.sh — pieza CORE del overlay (no opcional). Dos comprobaciones + theme activo:
#   1) ¿Está desplegado lo NUESTRO?   overlay ↔ vivo del theme ml4w-glass-juanjo.
#   2) ¿Cambió la BASE del upstream?   baseline ↔ vivo del theme ml4w-glass.
#   3) ¿Es el theme activo el nuestro?
# Correr ANTES de aplicar.sh tras cada update de ML4W.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
LIVE="$HOME/.config"
status=0

# 1) Lo NUESTRO: overlay ↔ vivo (¿desplegado?). Rutas relativas bajo overlay/.
OURS=(
  waybar/themes/ml4w-glass-juanjo/config
  waybar/themes/ml4w-glass-juanjo/modules-custom.json
  waybar/themes/ml4w-glass-juanjo/style.css
  waybar/themes/ml4w-glass-juanjo/scripts/cputemp.sh
  waybar/themes/ml4w-glass-juanjo/scripts/gputemp.sh
  waybar/themes/ml4w-glass-juanjo/scripts/livewallpaper.sh
  waybar/themes/ml4w-glass-juanjo/scripts/nightlight.sh
  waybar/themes/ml4w-glass-juanjo/default/style.css
  waybar/themes/ml4w-glass-juanjo/default/config.sh
  hypr/hyprsunset.conf
  hypr/conf/decorations/juanjo.lua
  cava/config
  ml4w-juanjo/cava-bg/cava-raw.conf
  ml4w-juanjo/quickshell/cavabg/shell.qml
  ml4w-juanjo/scripts/cava-toggle.sh
  ml4w-juanjo/scripts/despertar-pantallas.sh
  ml4w-juanjo/scripts/idle-guard.sh
  hypr/custom.lua
)
for f in "${OURS[@]}"; do
  over="$ROOT/overlay/$f"; live="$LIVE/$f"
  if [[ ! -f "$live" ]]; then
    echo "⤴  NO desplegado: $f  → ./aplicar.sh"; status=1
  elif ! diff -q "$over" "$live" >/dev/null; then
    echo "⤴  overlay ≠ vivo en $f  → ./aplicar.sh"; status=1
  fi
done

# 2) La BASE: baseline ↔ vivo del theme ml4w-glass (¿el upstream lo cambió?).
BASE=(
  waybar/themes/ml4w-glass/config
  waybar/themes/ml4w-glass/style.css
  waybar/themes/ml4w-glass/default/style.css
)
for f in "${BASE[@]}"; do
  base="$ROOT/baseline/$f"; live="$LIVE/$f"
  if [[ -f "$base" && -f "$live" ]] && ! diff -q "$base" "$live" >/dev/null; then
    echo "⚠  ML4W cambió la base $f  → revisar; ¿re-incorporar a nuestro theme + refrescar baseline (./capturar-baseline.sh)?"
    status=1
  fi
done

# 3) Verificar que el theme activo sea el nuestro.
grep -q "ml4w-glass-juanjo" "$HOME/.config/ml4w/settings/waybar-theme.sh" 2>/dev/null \
  || { echo "⚠  el theme activo NO es ml4w-glass-juanjo  → ./aplicar.sh"; status=1; }

# 4) Verificar que el daemon de luz nocturna (hyprsunset) esté activo vía systemd.
if ! systemctl --user is-active --quiet hyprsunset.service; then
  echo "⚠  hyprsunset.service NO activo  → ./aplicar.sh (o systemctl --user restart hyprsunset.service)"; status=1
fi

# 5) Fastfetch (logo rotativo). Aquí SÍ sobrescribimos un fichero de ML4W (config.jsonc), no
#    una carpeta aparte → comprobación de 3 estados. Correr ANTES de aplicar.sh.
ff_over="$ROOT/overlay/fastfetch/config.jsonc"
ff_base="$ROOT/baseline/fastfetch/config.jsonc"
ff_live="$LIVE/fastfetch/config.jsonc"
if [[ ! -f "$ff_live" ]]; then
  echo "⤴  NO desplegado: fastfetch/config.jsonc  → ./aplicar.sh"; status=1
elif diff -q "$ff_over" "$ff_live" >/dev/null; then
  :  # live == overlay → desplegado, OK
elif [[ -f "$ff_base" ]] && diff -q "$ff_base" "$ff_live" >/dev/null; then
  echo "⤴  fastfetch/config.jsonc no desplegado (vivo = base ML4W)  → ./aplicar.sh"; status=1
else
  echo "⚠  ML4W cambió fastfetch/config.jsonc  → revisar; re-incorporar la línea del glob a overlay/ + refrescar baseline (./capturar-baseline.sh)"; status=1
fi

# 6) Toggle de luz nocturna. Otro fichero de ML4W que SÍ sobrescribimos (con un shim que
#    delega en nightlight.sh) → comprobación de 3 estados, igual que fastfetch.
nl_over="$ROOT/overlay/ml4w/scripts/ml4w-toggle-hyprsunset"
nl_base="$ROOT/baseline/ml4w/scripts/ml4w-toggle-hyprsunset"
nl_live="$LIVE/ml4w/scripts/ml4w-toggle-hyprsunset"
if [[ ! -f "$nl_live" ]]; then
  echo "⤴  NO desplegado: ml4w/scripts/ml4w-toggle-hyprsunset  → ./aplicar.sh"; status=1
elif diff -q "$nl_over" "$nl_live" >/dev/null; then
  :  # live == overlay → shim desplegado, OK
elif [[ -f "$nl_base" ]] && diff -q "$nl_base" "$nl_live" >/dev/null; then
  echo "⤴  ml4w-toggle-hyprsunset no desplegado (vivo = base ML4W: mata el daemon y el botón no calienta)  → ./aplicar.sh"; status=1
else
  echo "⚠  ML4W cambió ml4w-toggle-hyprsunset  → revisar; re-incorporar el shim a overlay/ + refrescar baseline (./capturar-baseline.sh)"; status=1
fi

# 6b. ml4w-wallpaper. Tercer fichero de ML4W que sobrescribimos: parcheamos run_matugen para
#     que acepte `true` además de `1` en el flag de tema oscuro de gtk-3.0/settings.ini.
#     Sin el parche, en cuanto kde-gtk-config reescriba ese flag como `true` la siguiente
#     rotación de fondo regenera TODA la paleta en claro. Comprobación de 3 estados.
wp_over="$ROOT/overlay/ml4w/scripts/ml4w-wallpaper"
wp_base="$ROOT/baseline/ml4w/scripts/ml4w-wallpaper"
wp_live="$LIVE/ml4w/scripts/ml4w-wallpaper"
if [[ ! -f "$wp_live" ]]; then
  echo "⤴  NO desplegado: ml4w/scripts/ml4w-wallpaper  → ./aplicar.sh"; status=1
elif diff -q "$wp_over" "$wp_live" >/dev/null; then
  :  # live == overlay → parche desplegado, OK
elif [[ -f "$wp_base" ]] && diff -q "$wp_base" "$wp_live" >/dev/null; then
  echo "⤴  ml4w-wallpaper no desplegado (vivo = base ML4W: la paleta se regenerará en CLARO)  → ./aplicar.sh"; status=1
else
  echo "⚠  ML4W cambió ml4w-wallpaper  → revisar; re-incorporar el parche de run_matugen a overlay/ + refrescar baseline (./capturar-baseline.sh)"; status=1
fi

# 6e. hypridle.conf. Cuarto fichero de ML4W que sobrescribimos: los dos encendidos de pantalla
#     pasan por despertar-pantallas.sh en vez de disparar `dpms enable` a ciegas. Si ML4W lo
#     repone, vuelve el negro tras suspender (issue #1). Comprobación de 3 estados.
hi_over="$ROOT/overlay/hypr/hypridle.conf"
hi_base="$ROOT/baseline/hypr/hypridle.conf"
hi_live="$LIVE/hypr/hypridle.conf"
if [[ ! -f "$hi_live" ]]; then
  echo "⤴  NO desplegado: hypr/hypridle.conf  → ./aplicar.sh"; status=1
elif diff -q "$hi_over" "$hi_live" >/dev/null; then
  :  # live == overlay → arreglo desplegado, OK
elif [[ -f "$hi_base" ]] && diff -q "$hi_base" "$hi_live" >/dev/null; then
  echo "⤴  hypridle.conf no desplegado (vivo = base ML4W: volverá el negro al reanudar)  → ./aplicar.sh"; status=1
else
  echo "⚠  ML4W cambió hypridle.conf  → revisar; re-incorporar el encendido robusto a overlay/ + refrescar baseline (./capturar-baseline.sh)"; status=1
fi

# 6f. hypridle tiene que estar corriendo, o no hay ni bloqueo ni suspensión ni reanudación.
if ! pgrep -x hypridle >/dev/null; then
  echo "⚠  hypridle NO está corriendo  → ./aplicar.sh"; status=1
fi

# 6g. Estado del guardián de inactividad. NO es un fallo (desactivar la suspensión es justo para
#     lo que está el botón), pero conviene recordarlo: si te dejaste la suspensión desactivada,
#     este es el sitio donde se entera uno. Se limpia solo al cerrar sesión (vive en tmpfs).
idle_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ml4w-juanjo/inactividad"
idle_off=()
for f in pantallas bloqueo suspension; do
  [[ -f "$idle_dir/$f" ]] && idle_off+=("$f")
done
if (( ${#idle_off[@]} > 0 )); then
  echo "ℹ  inactividad DESACTIVADA para: ${idle_off[*]}  → botón 󰅶 de la barra, o cerrar sesión"
fi

# 6c. Coherencia de la paleta: si el flag de gtk-3.0 dice oscuro pero colors.json salió claro,
#     es que corrió un ml4w-wallpaper sin parchear. Se detecta por la luminosidad del fondo.
gtk_pref=$(grep -E '^gtk-application-prefer-dark-theme=' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null | awk -F'=' '{print $2}')
bg=$(grep -oP '"background":\s*"#\K[0-9a-fA-F]{6}' "$HOME/.config/ml4w/colors/colors.json" 2>/dev/null | head -1)
if [[ "$gtk_pref" =~ ^(1|true)$ && -n "$bg" ]] && (( 16#${bg:0:2} + 16#${bg:2:2} + 16#${bg:4:2} > 382 )); then
  echo "⚠  paleta CLARA (#$bg) con el tema oscuro pedido  → regenerar: ~/.config/ml4w/scripts/ml4w-wallpaper \"\$(cat ~/.cache/ml4w/hyprland-dotfiles/current_wallpaper)\""; status=1
fi

# 6d. Icon theme de GTK. Misma escritura de kde-gtk-config que rompe la paleta lo revierte a la
#     variante CLARA → los iconos de bandeja (nm-applet) se ven negros sobre la barra oscura.
icon_theme=$(grep -E '^gtk-icon-theme-name=' "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null | cut -d= -f2)
if [[ -n "$icon_theme" && "${icon_theme,,}" != *-dark ]]; then
  echo "⚠  icon theme GTK = '$icon_theme' (variante clara → iconos de bandeja negros)  → ./aplicar.sh"; status=1
fi

# Carpeta de logos: debe existir y tener ≥1 PNG, o el glob no casa y no habría imagen.
logos_dir="$LIVE/ml4w-juanjo/fastfetch-logos"
if ! compgen -G "$logos_dir/*.png" >/dev/null; then
  echo "⚠  sin PNG en $logos_dir  → ./aplicar.sh (el logo aleatorio de fastfetch quedaría vacío)"; status=1
fi

# 7) Binarios externos de los que dependen dos personalizaciones. aplicar.sh no los instala
#    (requieren sudo) → aquí solo avisamos.
#      · cava     → los dos modos del visualizador. Sin él el toggle abre un terminal que muere.
#      · mpvpaper → el botón de fondo de vídeo. Sin él el botón no enciende nada.
if ! command -v cava >/dev/null; then
  echo "⚠  cava NO instalado  → sudo pacman -S cava (SUPER+SHIFT+C / SUPER+ALT+C no funcionarán)"; status=1
fi
if ! command -v mpvpaper >/dev/null; then
  echo "⚠  mpvpaper NO instalado  → sudo pacman -S mpvpaper (el botón de fondo de vídeo no hará nada)"; status=1
fi

[[ $status -eq 0 ]] && echo "✔  todo en sync (theme propio desplegado y activo; base sin cambios; fastfetch rotativo; cava listo)."
exit $status
