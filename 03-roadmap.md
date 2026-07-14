# 03 — Roadmap de personalización

Ideas ordenadas por prioridad, para ir metiendo en el overlay tras las temperaturas.
Todo se hace vía `overlay/` + `aplicar.sh` (ver `01-estrategia-overlay.md`).

## A. Monitorización (continuación de la tarea 1)

- **Uso GPU + VRAM** en el tooltip o como módulo aparte:
  `nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits`.
- **Uso/velocidad de CPU por núcleo** en tooltip del módulo `cpu`.
- **Ventilador / RPM** si el `sensors` lo expone.
- Revisar el `group/hardware` para dejar un panel de estado del equipo coherente.

## A-bis. Luz nocturna (hyprsunset) — YA existe, mejorarla

Estado: `hyprsunset` instalado y funcional. Toggle por `SUPER+SHIFT+H` y por un botón que ya
está en la barra pero **plegado en el drawer `group/tools`** (módulo mal llamado
`custom/hyprshade`, tooltip "Toggle Screen Shader", pero su `on-click` llama a
`ml4w-toggle-hyprsunset`). Config: `~/.config/hypr/hyprsunset.conf` (`temperature = 5000`,
`gamma = 0.8`). Es **manual**, no programada.

Mejoras a aplicar vía overlay (aprobadas por el usuario):

1. **Botón visible en la barra** (no dentro del drawer): añadir un `custom/nightlight` propio
   en el `modules-custom.json` de **nuestro theme** (`overlay/waybar/themes/ml4w-glass-juanjo/`;
   icono claro tipo 󰌵/🌙, `on-click` = `~/.config/ml4w/scripts/ml4w-toggle-hyprsunset`,
   `tooltip` = "Luz nocturna") y colocarlo directamente en `modules-right` del `config` de
   nuestro theme, junto a las temperaturas.
2. **Automatización por horario**: configurar perfiles con `time` en `hyprsunset.conf` para
   activar/desactivar solo (p.ej. cálida 21:00–07:00). Ojo: `hyprsunset.conf` vive en
   `~/.config/hypr/`, así que hay que **añadirlo al overlay** (`overlay/hypr/hyprsunset.conf`
   + su ruta en `aplicar.sh`). Alternativa: un `systemd --user` timer o un script de
   arranque que lance `hyprsunset -t <temp>` según la hora.
   - Considerar temperatura más cálida (4000K/3500K) si 5000K se queda corta.

## B. Estética: bordes, colores, blur… (arquitectura ML4W verificada 2026-07)

> Investigado sobre el sistema real. No hace falta redescubrir cómo funciona; aquí está.

### Cómo funciona ML4W por dentro

**1. Sistema de "variantes".** Cada aspecto tiene un **cargador de una línea** que apunta a
un perfil intercambiable dentro de una carpeta de opciones:

| Cargador (`~/.config/hypr/conf/…`) | Carpeta de opciones | Controla |
|---|---|---|
| `window.lua` → `load_variant("transparent.lua","windows")` | `conf/windows/` | **bordes** (color, `border_size`, gaps, layout) |
| `decoration.lua` | `conf/decorations/` | **rounding, opacidad, sombra, blur** |
| `animation.lua` | `conf/animations/` | animaciones (10 estilos) |
| `layout.lua` | `conf/layouts/` | dwindle vs master, `laptop` |

Estado actual: `windows/transparent.lua` + `decorations/default.lua`. Cambiar de perfil =
editar **una línea**. Variantes de borde ya disponibles: `border-1..4(-reverse)`, `glass`,
`no-border`, `no-border-more-gaps`, `transparent`, `default`.

**2. Los colores son Material You generados por `matugen` a partir del wallpaper.**
`~/.config/hypr/colors.conf` / `colors.lua` / `~/.config/ml4w/colors/colors.json` **NO se
editan a mano**: son plantillas que matugen regenera al cambiar de fondo (config en
`~/.config/matugen/config.toml`). Por eso las variantes de borde usan **variables**
(`primary`, `on_primary`, `secondary`, `tertiary`…) en vez de colores fijos. Esto confirma la
vieja nota de "respetar el theme-switcher en vez de hardcodear".

### Qué se puede tocar (ejemplos reales)

- **Bordes** — en una variante de `conf/windows/`:
  ```lua
  border_size = 1,
  col = {
      active_border   = { colors = {"rgb(ffffff)", on_primary}, angle = 90 },  -- degradado
      inactive_border = on_primary,
  }
  ```
  Grosor, degradados con ángulo, y color fijo (`rgb(...)`) o variable del wallpaper.
- **Decoración** (`conf/decorations/default.lua`): `rounding=10`, `inactive_opacity=0.9`,
  sombra (rango/color), blur (`size`, `passes`, `vibrancy`).
- **Gaps**: `gaps_in=10`, `gaps_out=20` (dentro de la variante de window).

### Decisión de fondo antes de tocar colores

- **Colores atados al wallpaper (matugen)** → coherente y automático, pero cambian al cambiar
  fondo; para bordes se usan variables (`primary`, etc.).
- **Colores fijos propios** → control total (p.ej. borde activo siempre cian), pero hay que
  hardcodear `rgb(...)` en la variante (como hace `transparent.lua` con el blanco) o
  desconectar matugen.

**Recomendación (encaja con el overlay):** crear **variantes propias** en vez de editar las de
ML4W — p.ej. `overlay/hypr/conf/windows/juanjo.lua` — y que el cargador de una línea
(`conf/window.lua`) apunte a la nuestra. Así los updates de ML4W no pisan el perfil y `check.sh`
solo vigila el cargador de una línea, no un archivo grande. Añadir `~/.config/hypr/conf/` al
`aplicar.sh` y a la lista de `check.sh`.

### Otros

- **Fuentes**: confirmar Nerd Font para que los glyphs (󰔏 󰢮) se rendericen bien.
- Valorar otro tema ML4W como base (`ml4w-modern`, `ml4w-glass`, `ml4w-minimal`, etc.).

## C. Portátil / calidad de vida

- **Batería**: formato con tiempo estimado y estados de carga.
- **Backlight**: el módulo `backlight` está comentado en `modules-right`; activarlo.
- **Red**: afinar el módulo `network` (SSID, velocidad).
- **Perfiles de energía** (TLP / power-profiles-daemon) y su indicador en barra.

## D. Hyprland (config Lua, con cuidado)

- **Atajos propios** respetando la estructura `~/.config/hypr/conf/keybindings*` (Lua).
- **Reglas de ventana / workspaces** a gusto.
- **hypridle / hyprlock / hyprpaper**: tiempos de bloqueo, wallpaper, lockscreen.

## E. Higiene del overlay

- **`check.sh` = parte del núcleo, no un extra** (subido de prioridad): se implementa junto
  con `aplicar.sh` y `capturar-baseline.sh` en la fase de montar el overlay, no después.
  Es lo que convierte el modelo "re-aplicar a mano tras cada update" de frágil a robusto:
  avisa de deriva del upstream (vivo ≠ baseline) y de overlay no desplegado (overlay ≠ vivo).
  Esqueleto y semántica en `01-estrategia-overlay.md`.
- Documentar en cada commit qué archivo de ML4W se toca y por qué.
- Mantener `baseline/` actualizado tras cada update de ML4W para detectar cambios upstream.
- Más adelante: enganchar `check.sh` a un hook de pacman/paru o a un `systemd --user` para
  que avise solo cuando ML4W se actualiza (hoy: ejecución manual antes de `aplicar.sh`).

## Cosas a decidir con el usuario

- Repo GitHub: **público o privado** y nombre definitivo.
- Comportamiento del módulo GPU en batería (ver aviso en `02-tarea-temperaturas.md`).
- Nivel de "bonito" vs "funcional": ¿retoque ligero del tema actual o rediseño estético?
