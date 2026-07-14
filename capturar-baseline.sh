#!/usr/bin/env bash
# capturar-baseline.sh — snapshot del theme base ml4w-glass tal y como lo sirve ML4W.
# Sirve de referencia "virgen" para que check.sh detecte si un update de ML4W cambia la
# base de la que copiamos nuestro theme. Ejecutar tras cada update de ML4W.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
LIVE="$HOME/.config"

BASE=(
  waybar/themes/ml4w-glass/config
  waybar/themes/ml4w-glass/style.css
  waybar/themes/ml4w-glass/default/style.css
)

for f in "${BASE[@]}"; do
  src="$LIVE/$f"; dst="$ROOT/baseline/$f"
  if [[ ! -f "$src" ]]; then
    echo "⚠  no existe en vivo: $f (¿cambió ML4W la estructura?)"; continue
  fi
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
  echo "✔  baseline: $f"
done
echo "Baseline capturado en baseline/."
