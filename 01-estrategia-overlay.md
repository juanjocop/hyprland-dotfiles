# 01 — Estrategia "repo overlay"

## Por qué overlay y no fork

El instalador de ML4W **sobrescribe `~/.mydotfiles/com.ml4w.dotfiles.stable` en cada update**,
ignorando git. Consecuencias:

- **Fork del upstream de ML4W** → pelea con el updater oficial y obliga a mantener todo el
  repo enorme. Descartado.
- **git init sobre todo `~/.mydotfiles`** → cada update genera diffs gigantes y merges a
  mano. Descartado.
- **Overlay (elegido)** → un repo propio, pequeño, con SOLO los archivos que tocamos + un
  script que los re-aplica sobre el árbol de ML4W. Los updates de ML4W nunca chocan; nuestro
  trabajo vive aislado y reproducible en GitHub.

## Estructura del repo

```
~/Proyectos/hyprland-dotfiles/          (= repo git → GitHub)
  README.md
  00-contexto-y-hardware.md
  01-estrategia-overlay.md
  02-tarea-temperaturas.md
  03-roadmap.md
  overlay/                 # copias versionadas de lo que personalizamos (nuestra versión)
    waybar/
      themes/ml4w-glass-juanjo/           # NUESTRO theme propio (autocontenido, ver doc 02)
        config                            # layout de la barra (basado en ml4w-glass)
        modules-custom.json               # nuestros módulos (temperature, custom/gputemp)
        default/style.css                 # aspecto visual (basado en ml4w-glass)
        default/config.sh                 # theme_name="Glass Juanjo"
  baseline/                # copia "virgen" de los archivos de ML4W que usamos de BASE
    waybar/
      themes/ml4w-glass/config            # referencia del que copiamos (para ver si upstream lo cambia)
      themes/ml4w-glass/default/style.css
  aplicar.sh               # copia overlay/ → ~/.config/..., fija el theme activo y recarga waybar
  capturar-baseline.sh     # copia el estado en vivo actual → baseline/ (tras un update de ML4W)
  check.sh                 # avisa si ML4W cambió (upstream) un archivo que nuestro overlay pisa
  .gitignore
```

- `overlay/` = lo nuestro (fuente de la verdad de nuestras personalizaciones).
- `baseline/` = referencia del ML4W "limpio" para detectar cambios del upstream (3-way).

> **Ventaja clave del enfoque "theme propio"** (ver doc 02): nuestro theme
> `ml4w-glass-juanjo` es una carpeta **nueva** que ML4W nunca edita → prácticamente **no hay
> deriva upstream** en lo nuestro. `baseline/` solo guarda el theme `ml4w-glass` del que
> copiamos, para enterarnos si un update de ML4W mejora esa base y queremos re-incorporarlo.

## Pasos de ejecución (próxima sesión)

1. **Inicializar repo**
   ```bash
   cd ~/Proyectos/hyprland-dotfiles
   git init -b main
   ```
2. **Capturar baseline** del theme base `ml4w-glass` (antes de tocar nada):
   ```bash
   ./capturar-baseline.sh      # copia themes/ml4w-glass/{config,default/style.css} → baseline/
   ```
3. **Crear nuestro theme** copiando la base a `overlay/waybar/themes/ml4w-glass-juanjo/`
   (config + default/style.css + config.sh) y editar SOLO ahí (nunca a mano en vivo). Añadir
   `modules-custom.json` con las temperaturas (ver `02-tarea-temperaturas.md`).
4. **Desplegar**: `./aplicar.sh` (copia el theme → vivo, lo fija como activo, relanza waybar)
   y validar.
5. **Commit + GitHub**:
   ```bash
   git add -A && git commit -m "overlay: base + temperaturas CPU/GPU"
   gh repo create hyprland-dotfiles --private --source=. --push   # decidir público/privado
   ```

## Flujo tras cada actualización de ML4W

**`check.sh` es la pieza que hace robusto todo esto** (no es opcional): el modelo depende de
re-aplicar el overlay a mano tras cada update, y nada avisa si te olvidas o si ML4W cambió por
debajo un archivo que nosotros pisamos. `check.sh` es ese aviso.

```bash
# 1. Ver qué cambió el upstream y si choca con lo nuestro
./check.sh
# 2. Si el upstream cambió un archivo que pisamos, incorporar el cambio a overlay/ Y baseline/
# 3. Re-desplegar lo nuestro
./aplicar.sh
```

## `aplicar.sh` (esqueleto a implementar)

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.config"

# 1. Copiar nuestro theme propio (carpeta autocontenida) al árbol de waybar
rsync -a "$ROOT/overlay/waybar/themes/ml4w-glass-juanjo/" \
         "$DEST/waybar/themes/ml4w-glass-juanjo/"

# 2. Fijar nuestro theme como activo (formato /CARPETA;/CARPETA/VARIACIÓN)
echo "/ml4w-glass-juanjo;/ml4w-glass-juanjo/default" \
     > "$HOME/.config/ml4w/settings/waybar-theme.sh"

# 3. Relanzar waybar leyendo el theme activo (launch.sh) — no vale SIGUSR2 porque
#    cambiamos de theme, no solo de contenido
"$DEST/waybar/launch.sh" &
echo "Overlay aplicado (theme ml4w-glass-juanjo activo)."
```

> Nota: como `~/.config/waybar` es un symlink al árbol de ML4W, `rsync` escribe en el árbol
> real de ML4W. Es lo que queremos: overlay = fuente, vivo = destino re-aplicable. La
> diferencia con el plan viejo es que ahora **añadimos una carpeta nueva** en vez de pisar
> archivos de ML4W.

## `check.sh` (esqueleto a implementar)

Con el enfoque "theme propio" hay **dos comprobaciones independientes**:

1. **¿Está desplegado lo nuestro?** — comparar cada archivo de `overlay/…/ml4w-glass-juanjo/`
   con su copia en vivo. Si difieren → falta `aplicar.sh` (o un update lo podó). Aquí NO hay
   deriva de upstream porque es una carpeta nuestra que ML4W no toca.
2. **¿Cambió la base de la que copiamos?** — comparar `baseline/…/ml4w-glass/` con el
   `ml4w-glass` en vivo. Si difieren → ML4W actualizó el theme base; conviene revisar el
   cambio por si queremos re-incorporarlo a nuestro theme y refrescar el baseline.

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
LIVE="$HOME/.config"
status=0

# 1) Lo NUESTRO: overlay ↔ vivo (¿desplegado?). Rutas relativas bajo overlay/.
OURS=(
  waybar/themes/ml4w-glass-juanjo/config
  waybar/themes/ml4w-glass-juanjo/modules-custom.json
  waybar/themes/ml4w-glass-juanjo/default/style.css
  waybar/themes/ml4w-glass-juanjo/default/config.sh
)
for f in "${OURS[@]}"; do
  over="$ROOT/overlay/$f"; live="$LIVE/$f"
  if [[ ! -f "$live" ]]; then echo "⤴  NO desplegado: $f  → ./aplicar.sh"; status=1
  elif ! diff -q "$over" "$live" >/dev/null; then
    echo "⤴  overlay ≠ vivo en $f  → ./aplicar.sh"; status=1
  fi
done

# 2) La BASE: baseline ↔ vivo del theme ml4w-glass (¿el upstream lo cambió?).
BASE=(
  waybar/themes/ml4w-glass/config
  waybar/themes/ml4w-glass/default/style.css
)
for f in "${BASE[@]}"; do
  base="$ROOT/baseline/$f"; live="$LIVE/$f"
  if [[ -f "$base" && -f "$live" ]] && ! diff -q "$base" "$live" >/dev/null; then
    echo "⚠  ML4W cambió la base $f  → revisar; ¿re-incorporar a nuestro theme + refrescar baseline?"
    status=1
  fi
done

# Verificar además que el theme activo sea el nuestro
grep -q "ml4w-glass-juanjo" "$HOME/.config/ml4w/settings/waybar-theme.sh" 2>/dev/null \
  || { echo "⚠  el theme activo NO es ml4w-glass-juanjo → ./aplicar.sh"; status=1; }

[[ $status -eq 0 ]] && echo "✔  todo en sync (theme propio desplegado y activo; base sin cambios)."
exit $status
```

> Correr `./check.sh` **antes** de `aplicar.sh` tras cada update de ML4W. Idealmente también
> engancharlo a un hook de pacman/paru o a un `systemd --user` para que avise solo cuando
> ML4W se actualiza; de momento, ejecución manual.
