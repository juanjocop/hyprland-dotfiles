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
  waybar/themes/ml4w-glass-juanjo/scripts/gputemp.sh
  waybar/themes/ml4w-glass-juanjo/default/style.css
  waybar/themes/ml4w-glass-juanjo/default/config.sh
  hypr/hyprsunset.conf
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

# Carpeta de logos: debe existir y tener ≥1 PNG, o el glob no casa y no habría imagen.
logos_dir="$LIVE/ml4w-juanjo/fastfetch-logos"
if ! compgen -G "$logos_dir/*.png" >/dev/null; then
  echo "⚠  sin PNG en $logos_dir  → ./aplicar.sh (el logo aleatorio de fastfetch quedaría vacío)"; status=1
fi

[[ $status -eq 0 ]] && echo "✔  todo en sync (theme propio desplegado y activo; base sin cambios; fastfetch rotativo)."
exit $status
