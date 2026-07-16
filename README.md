# hyprland-dotfiles — personalización de ML4W sobre CachyOS

Personalización de los dotfiles **ML4W** (Hyprland) del equipo de juanjocop, sobre **CachyOS**.

Este repo es un **overlay**: guarda **solo** lo que cambiamos por encima de ML4W, más los
scripts para re-aplicarlo. Así, cuando ML4W se actualiza y sobrescribe su árbol, recuperamos
nuestro trabajo con un comando en vez de perderlo.

> **Por qué overlay y no fork:** el instalador de ML4W sobrescribe su árbol
> (`~/.mydotfiles/com.ml4w.dotfiles.stable`) en cada update **ignorando git**. Un fork
> pelearía con eso. En su lugar versionamos solo nuestros ficheros y los volvemos a colocar
> con `./aplicar.sh`.

---

## Qué incluye (todo desplegado y en producción)

| Personalización | Qué hace | Dónde |
|---|---|---|
| **Waybar: temperaturas** | Temp de CPU y GPU (Optimus: Intel iGPU + NVIDIA dGPU) en la barra | theme propio `ml4w-glass-juanjo` |
| **Waybar: botón fondo de vídeo** | Enciende/apaga un fondo de vídeo (mpvpaper) desde un botón de la barra | `scripts/livewallpaper.sh` |
| **Luz nocturna (hyprsunset)** | Filtro de luz azul automático por horario **21:00 → 07:00** (4000 K) | `overlay/hypr/hyprsunset.conf` + systemd |
| **Fastfetch: logo rotativo** | Muestra una imagen distinta al azar en cada arranque de terminal | `overlay/fastfetch/` |
| **Visualizador de audio (cava)** | Barras que se mueven al ritmo, como ventana tilada más. **SUPER+SHIFT+C** | `overlay/cava/` + `overlay/hypr/custom.lua` |

---

## Los tres comandos

Todos se ejecutan desde la raíz del repo (`~/Proyectos/hyprland-dotfiles`).

| Comando | Para qué | Cuándo |
|---|---|---|
| **`./check.sh`** | Comprueba si lo nuestro está desplegado y si un update de ML4W ha tocado nuestra base | **Antes** de aplicar, y tras cada update de ML4W |
| **`./aplicar.sh`** | Copia el overlay al sistema en vivo, fija nuestro theme, arranca hyprsunset y sincroniza los logos | Tras editar el overlay o tras un update de ML4W |
| **`./capturar-baseline.sh`** | Refresca `baseline/` con la versión actual de ML4W (referencia para detectar deriva) | Solo cuando ML4W cambió su base y ya la reincorporamos |

### Flujo tras una actualización de ML4W

```bash
cd ~/Proyectos/hyprland-dotfiles
./check.sh      # 1. ver qué se descolocó o qué cambió ML4W
./aplicar.sh    # 2. volver a dejar todo lo nuestro en su sitio
./check.sh      # 3. confirmar: "todo en sync"
```

Si `check.sh` avisa de que **ML4W cambió una base** (p. ej. `ml4w-glass` o `fastfetch/config.jsonc`),
revisa el cambio, reincorpóralo a `overlay/` si interesa y luego `./capturar-baseline.sh`.

---

## Fastfetch: cambiar o añadir logos

El logo rota al azar gracias a un **glob nativo** de fastfetch: `logo.source` apunta a
`~/.config/ml4w-juanjo/fastfetch-logos/*.png`, y si hay varias imágenes elige una por ejecución.
Sin wrapper ni scripts.

**Set inicial:** CachyOS · Hyprland · Arch · Tux — a color, con transparencia, normalizados a
un lienzo cuadrado 512×512.

**Añadir una imagen** (déjala cuadrada y transparente para que combine con el resto):

```bash
# normaliza tu PNG al mismo formato del set y ponlo en el overlay
magick tu-logo.png -trim +repage -resize 460x460 -background none \
       -gravity center -extent 512x512 \
       overlay/fastfetch/logos/tu-logo.png

./aplicar.sh    # entra en la rotación
```

Notas:
- El glob solo casa **`*.png`**. Añade imágenes en PNG.
- El tamaño en pantalla se ajusta con `width`/`height` en `overlay/fastfetch/config.jsonc`
  (ahora `18`×`9`, con `preserveAspectRatio`). El render depende del protocolo de tu terminal
  (kitty/sixel).
- Buenas fuentes: [Dashboard Icons](https://dashboardicons.com), logos SVG oficiales de cada
  proyecto exportados a PNG transparente.

---

## Visualizador de audio (cava)

**SUPER+SHIFT+C** abre/cierra las barras que se mueven al ritmo. Requiere el paquete `cava`
(`sudo pacman -S cava`); `aplicar.sh` no lo instala porque necesita sudo, pero `check.sh` avisa
si falta.

**Es una ventana normal**: nace **tilada en el workspace en el que estés** y se coloca con las
demás. Se mueve, redimensiona y manda a otro workspace con los atajos normales de Hyprland.

**Visualiza cualquier audio del sistema.** cava lee del monitor de PipeWire, no de un reproductor:
da igual que suene Zen, VLC, un juego o una web. No hay nada que configurar por reproductor.

**No toca la GPU dedicada** (verificado 2026-07 comparando `nvidia-smi` con y sin cava): cava dibuja
texto con ncurses = CPU pura, y kitty renderiza en la GPU del compositor, que es la Intel. Nada va
a la NVIDIA sin pedirlo con las variables de PRIME offload.

Cómo está montado:

- `overlay/cava/config` → `~/.config/cava/config`. Gradiente de 4 colores, `background = default`
  para heredar la transparencia de kitty (look glass).
- `overlay/hypr/custom.lua` → el **hook oficial** de ML4W (lo carga el último). Solo define el bind:
  **no hay window_rule**, porque sin regla Hyprland ya la tila donde queremos.
- `overlay/ml4w-juanjo/scripts/cava-toggle.sh` → el toggle.

**El toggle mata cava al cerrar** en vez de esconderlo: en un portátil no tiene sentido gastar CPU
en barras que no se ven. Por eso el estado se consulta con `pgrep cava`, y cerrar = `pkill cava`
(kitty se cierra sola al morir el proceso que lanzó con `-e`).

> **Descartado: el workspace especial.** La primera versión metía cava en un `special:cava` con
> toggle de scratchpad. Tapaba la pantalla entera, porque una ventana sola en un workspace propio
> ocupa todo el espacio — y flotarla la hacía aún más grande (1920x1080). Se cambió a ventana tilada
> normal, que además dejó el montaje más simple (sin regla y sin `toggle_special`).

Para cambiar los colores, edita el gradiente en `overlay/cava/config` y `./aplicar.sh`. Atarlo a la
paleta del wallpaper (matugen) está en el roadmap: quedaría mejor pero obliga a tocar un fichero de
ML4W → deriva.

---

## Estructura del repo

```
overlay/                     ← fuente de verdad: solo lo que personalizamos
  waybar/themes/ml4w-glass-juanjo/   theme propio (temps + botón fondo vídeo)
  hypr/hyprsunset.conf               horario de luz nocturna
  hypr/custom.lua                    hook oficial de ML4W: bind de cava
  cava/config                        config del visualizador (gradiente, fuente de audio)
  ml4w-juanjo/scripts/cava-toggle.sh script del toggle SUPER+SHIFT+C
  fastfetch/config.jsonc             config con el glob del logo
  fastfetch/logos/*.png              conjunto de logos para la rotación
baseline/                    ← copia "virgen" de la base de ML4W (para detectar deriva)
aplicar.sh · check.sh · capturar-baseline.sh
00-…03-*.md · CLAUDE.md      ← contexto, decisiones y notas de diseño
```

### Detalles que conviene saber

- **`~/.config/waybar`, `~/.config/fish`, `~/.config/fastfetch` son symlinks al árbol de ML4W.**
  Editar ahí = editar ML4W (y el updater lo puede pisar). Por eso todo pasa por el overlay.
- **Las imágenes de fastfetch viven en `~/.config/ml4w-juanjo/`**, un namespace **propio fuera
  de ML4W** que el updater nunca poda → cero deriva en las imágenes.
- **hyprsunset** usa la unit systemd que trae el paquete
  (`/usr/lib/systemd/user/hyprsunset.service`); nosotros solo desplegamos el `.conf` con el
  horario y activamos el servicio desde `aplicar.sh`.

---

## Reglas de oro

- **Nunca editar el sistema en vivo (`~/.config`) a mano.** Todo cambio va a `overlay/` y se
  despliega con `./aplicar.sh`. El vivo es un destino re-aplicable, no la fuente.
- **`check.sh` es parte del núcleo**, no un extra opcional. Córrelo antes de aplicar.
- La documentación se escribe en **español**.

---

## Documentos de referencia

Historia y decisiones de diseño (no hace falta leerlos para el uso diario):

1. `00-contexto-y-hardware.md` — equipo, rutas de ML4W, comandos de sensores verificados.
2. `01-estrategia-overlay.md` — diseño del overlay y de `aplicar.sh`.
3. `02-tarea-temperaturas.md` — cómo se montaron las temperaturas en la waybar.
4. `03-roadmap.md` — siguientes pasos de personalización.
5. `CLAUDE.md` — guía para Claude Code al trabajar en este repo.
