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

1. **Botón visible en la barra** — **OMITIDO** (decisión del usuario, 2026-07): ya es
   accesible por el toggle `SUPER+SHIFT+H` y el botón del drawer `group/tools`.
2. **Automatización por horario** — ✅ **IMPLEMENTADO (2026-07)**. hyprsunset v0.4.0 soporta
   perfiles por horario nativos; se versiona `overlay/hypr/hyprsunset.conf` con dos perfiles:
   día 07:00 (`identity`, sin filtro) y noche 21:00 (`temperature = 4000`, `gamma = 1.0`).
   El daemon corre persistente vía la **unit systemd empaquetada** `hyprsunset.service`
   (no es archivo de ML4W → cero deriva); `aplicar.sh` despliega el config, hace
   `enable`+`restart` del service; `check.sh` verifica que esté desplegado y activo;
   `capturar-baseline.sh` guarda el default de ML4W en `baseline/hypr/hyprsunset.conf`.
   - **Caveat**: el toggle `SUPER+SHIFT+H` (`ml4w-toggle-hyprsunset`) hace `pkill`/`hyprsunset &`;
     al reactivar lanza una instancia manual (no systemd) que igualmente lee el schedule.
     Re-sincronizar con `./aplicar.sh` o `systemctl --user restart hyprsunset.service`.
     Hacer el toggle systemd-aware queda como mejora futura (requeriría versionar el script).

## A-ter. Música y visualizador — cava YA existe, ampliaciones posibles

Estado: **cava implementado (2026-07) en sus dos modos**, ventana (SUPER+SHIFT+C) y fondo
(SUPER+ALT+C), excluyentes entre sí. El modo fondo es un **widget Quickshell propio** que convive
con el vídeo de mpvpaper y se colorea con matugen. Ver README y `00-contexto-y-hardware.md` §Audio.
Verificado que **no toca la dGPU**.

### Descartado: cava-bg (2026-07)

[leriart/cava-bg](https://github.com/leriart/cava-bg) hacía justo esto, pero se descartó:

- **Confianza**: proyecto de abril de 2026, 58★, **2 votos en AUR**. El PKGBUILD se auditó y está
  limpio (el sha256 del tarball **coincide** con el de upstream → compila el código real, sin
  parches; sin hooks `.install`, sin red, sin telemetría remota — su `telemetry` es logging local).
  Nada sospechoso, pero es código joven con pocos ojos encima, y **el widget propio da lo mismo con
  Quickshell de repos oficiales**. Coste ~150 líneas de QML frente a confiar en un desconocido.
- **Sus efectos vistosos no aplican aquí**: `parallax` y `x-ray` no son efectos de barras sino de
  **composición de imágenes** (confirmado: `layer_system.rs` y `parallax_system.rs` cargan
  texturas). X-Ray usa las barras de máscara para revelar una imagen oculta; parallax desplaza
  capas de imagen con ratón/audio para fingir 3D. Ambos existen para dar vida a wallpapers
  **estáticos** — aquí el fondo ya es vídeo. Además su propia doc marca el sistema de capas como
  *"not yet wired to the renderer"* y `parallax.mode` como *"not currently read by the renderer"*.
- **Alternativas revisadas y también descartadas**: **GLava** (el clásico de los vídeos de rices) es
  **solo X11**; **hyprglaze** es igual de nuevo (abril 2026); **shaderbg/glbg/neowall** son shaders
  sin audio-reactividad de serie. **No existe una opción Wayland madura** para esto: todo el
  ecosistema es de 2026. Por eso el widget propio.
- **Vía mpv descartada también**: `mpvpaper -o "--lavfi-complex=…"` con los filtros de ffmpeg
  (`showcqt`, `showspectrum`…) funciona y es cero dependencias — verificado que
  `mpv av://pulse:<monitor>` lee el audio del sistema. Pero mpvpaper reproduce **una cosa por
  salida**: sería el visualizador **en lugar** del vídeo, no encima. Queda anotado por si algún día
  se prefiere eso.

### Mejoras posibles sobre el widget

1. **Modo idle** — hoy cava corre a 60 fps mientras el fondo esté encendido, aunque no suene nada.
   El toggle lo compensa (coste cero apagado). Mejora: pausar el repintado cuando todas las barras
   estén a 0 durante N segundos.
2. **Más formas** — el widget está en `overlay/ml4w-juanjo/quickshell/cavabg/shell.qml` con los
   ajustes (`stripHeight`, `barCount`, `gap`, `smoothMs`, `peakFall`) juntos arriba. Variantes
   posibles: espejo desde el centro, altura completa, barras por monitor.
3. **De dónde saca matugen la paleta** — ver el aviso en §B: el wallpaper que la genera
   (`awww-daemon`) está **tapado por el vídeo de mpvpaper**. La paleta sale de una foto que no se
   ve. No es un problema del widget (al contrario: así pega con waybar), pero es una rareza del
   setup que quizá convenga replantear.
3. **Módulo de música en waybar (`mpris`)** — waybar depende de `playerctl` y `libmpdclient`, así
   que el módulo `mpris` **sí está disponible**. ⚠️ Filtrar por **`firefox`**, no por `zen` (ver
   `00-contexto-y-hardware.md` §MPRIS). La sidebar de Quickshell de ML4W ya muestra MPRIS, así que
   esto solo aporta si se quiere en la barra.
4. **Barras de cava EN la waybar** — ⚠️ **el módulo `cava` nativo NO es viable**: verificado que el
   binario de Arch/CachyOS **no lo trae compilado** (`waybar -c` con un módulo `cava` responde
   `Disabling module "cava", Unknown module`). Haría falta un módulo `custom/` alimentado del
   output `raw` de cava (patrón: [fr33root5/cava-setup](https://github.com/fr33root5/cava-setup)),
   o compilar waybar a mano.
5. **Reproductor de música propiamente dicho** — decisión **abierta**: el usuario se plantea montar
   su propia app self-hosted accesible por navegador desde cualquier sitio. Si lo hace, **MPD+rmpc
   pierde sentido** (sería una segunda biblioteca en paralelo). Nota de diseño clave para esa app:
   implementar la **Media Session API** (`navigator.mediaSession.metadata` + handlers) → aparece
   sola en la sidebar de ML4W, en waybar y en las teclas multimedia, como si fuera nativa. Firefox
   ya expone MPRIS sin tocar nada. Alternativa existente: **Navidrome** (+ hablar la API de
   Subsonic para heredar su ecosistema de clientes).

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
