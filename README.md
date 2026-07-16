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
| **Visualizador de audio (cava)** | Barras al ritmo, en dos modos excluyentes: ventana (**SUPER+SHIFT+C**) y fondo (**SUPER+ALT+C**) | `overlay/cava/` + `overlay/ml4w-juanjo/` + `overlay/hypr/custom.lua` |

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

Dos modos, **excluyentes** (encender uno apaga el otro — no tiene sentido tener dos visualizadores
pintando lo mismo):

| Atajo | Modo | Qué es |
|---|---|---|
| **SUPER+SHIFT+C** | **Ventana** | cava en una kitty, **tilada en el workspace actual**. Se mueve/redimensiona como cualquier ventana. |
| **SUPER+ALT+C** | **Fondo** | Franja de barras de 250px abajo, **sobre el vídeo de mpvpaper y debajo de las ventanas**. Widget Quickshell propio. |

Requiere el paquete `cava` (`sudo pacman -S cava`); `aplicar.sh` no lo instala porque necesita sudo,
pero `check.sh` avisa si falta. Quickshell ya viene con ML4W (repos oficiales de Arch).

**Visualiza cualquier audio del sistema.** cava lee del monitor de PipeWire, no de un reproductor:
da igual que suene Zen, VLC, un juego o una web. No hay nada que configurar por reproductor.

**Nada de esto toca la GPU dedicada** (verificado 2026-07 comparando la tabla de procesos de
`nvidia-smi` con y sin cava: idéntica, 0% de uso). El modo ventana es CPU pura (ncurses); ambos
renderizan en la GPU del compositor, que es la Intel. Nada va a la NVIDIA sin pedirlo con las
variables de PRIME offload.

### Cómo está montado

- `overlay/cava/config` → `~/.config/cava/config` — config del **modo ventana** (salida ncurses,
  gradiente fijo, `background = default` para heredar la transparencia de kitty).
- `overlay/ml4w-juanjo/cava-bg/cava-raw.conf` → config del **modo fondo**: salida `raw` (imprime
  `"12;20;…;"` por stdout en vez de dibujar). `bars` **debe coincidir** con `barCount` del QML.
- `overlay/ml4w-juanjo/quickshell/cavabg/shell.qml` → el widget del fondo.
- `overlay/ml4w-juanjo/scripts/cava-toggle.sh` → **un solo** script con argumento (`tile` | `bg`),
  para que la lógica de exclusión mutua viva en un único sitio.
- `overlay/hypr/custom.lua` → el **hook oficial** de ML4W (lo carga el último): los dos binds.

**Los cierres matan cava** en vez de esconderlo: en un portátil no tiene sentido gastar CPU en
barras que no se ven. Con ambos modos apagados, `pgrep cava` no devuelve nada.

> ⚠️ **Nunca usar `pgrep -x cava` / `pkill -x cava` en el toggle.** Los dos modos lanzan un proceso
> `cava`, así que razonar sobre "cualquier cava" mata el del otro modo. Cada modo apunta solo a **su**
> proceso con `pgrep -f <patrón>` (`kitty --class cava-visualizer` / `qs -p …/cavabg`).

### El modo fondo, por dentro

- **Convive con el vídeo** porque usa `WlrLayer.Bottom` → **nivel 1**, por encima de `mpvpaper`
  (nivel 0) y por debajo de `waybar` (nivel 2) y de las ventanas. `exclusionMode: Ignore` para no
  reservar espacio.
- **Los colores salen de matugen**: el QML lee `~/.config/ml4w/colors/colors.json` con un `FileView`
  que vigila cambios → al cambiar de wallpaper, matugen regenera la paleta y **las barras se
  re-colorean solas**, sin reiniciar nada. Así pegan con waybar y los bordes.
  ⚠️ **Ojo al elegir colores de esa paleta**: es Material You *oscura*, así que `primary` (#b1c5ff) y
  `tertiary` (#e1bbdd) son colores de **primer plano** — dos pasteles claros de luminosidad casi
  idéntica que en degradado se leen como **un color plano** (pasó en la v1). El contraste está en
  los `_container`: de ahí el degradado de 3 paradas `primary_container` (marino) → `primary` →
  `tertiary`.
- **Las barras van difuminadas y los picos no**: los picos se dibujan aparte, fuera del blur, para
  que queden nítidos. Metidos dentro desaparecían — una línea de 2px con un blur de radio ~10px se
  reparte sobre ~20px y su intensidad cae a ~1/10.

### Ajustes del modo fondo

Todos juntos arriba del `shell.qml`. Ciclo para probar: editar → `./aplicar.sh` → SUPER+ALT+C dos
veces (apagar y encender).

| Ajuste | Valor | Qué hace |
|---|---|---|
| `stripHeight` | 250 | Alto de la franja en px |
| `barCount` | 64 | Nº de barras. **Si lo tocas, toca también `bars` en `cava-raw.conf`** |
| `gap` | 6 | Separación entre barras |
| `smoothMs` | 90 | Suavizado entre frames de cava |
| `peakFall` | 1.2 | A cuánto cae el pico por frame |
| `barBlur` | 0.4 | Desenfoque, 0-1 (fracción de `blurMaxPx`) |
| `blurMaxPx` | 24 | Px de blur a los que equivale `barBlur = 1` |
| `stripOpacity` | 0.7 | Transparencia del conjunto |
| `glowEnabled` | false | Halo tipo neón (ver abajo) |

**`barBlur` y `stripOpacity` van emparejadas**: cuanto más blur, menos se nota la transparencia — el
desenfoque reparte el color sobre más superficie y se lee como mancha sólida. Al subir uno, baja la
otra.

### Tres cosas que NO hay que "arreglar"

Son decisiones, no descuidos. Están comentadas en el código; aquí el resumen:

1. **`autoPaddingEnabled: false` en el `MultiEffect`.** En `true` (su default) amplía el área de
   render para que el blur no se recorte, pero **desplaza las barras hacia abajo**. Como los picos
   se dibujan sin pasar por el efecto, ellos quedaban en su sitio y las barras no → descuadre
   visible. Verificado con capturas.
2. **El blur se hace en Qt, no con `hl.layer_rule` de Hyprland.** El layer_rule (el idiom que ML4W
   usa para la waybar) difumina lo que hay *detrás* y depende del blur **global**, que la variante
   de decoración activa (`conf/decorations/juanjo.lua`) tiene apagado **a propósito** ("gamemode,
   wallpaper nítido detrás"). Activarlo afectaría a todo el escritorio para lograr un efecto en una
   franja.
3. **El glow está montado pero apagado.** Probado y descartado (2026-07): duplica la composición
   (renderiza las barras dos veces por frame) sin aportar lo suficiente. Queda a un
   `glowEnabled = true` de distancia. Blur y glow **no son lo mismo**: el blur emborrona la barra
   entera; el glow la deja nítida y pone el desenfoque **alrededor**, como halo de neón.

> **Depuración**: para ver cómo queda algo, **haz una captura** en vez de adivinar —
> `grim -g "0,830 1920x250" /tmp/x.png` recorta justo la franja. Y `qs` lanzado en segundo plano
> desde un shell no interactivo puede morir al salir el padre; lanzado por Hyprland (lo que hace la
> keybind) va bien. Para probarlo a mano:
> `hyprctl dispatch 'hl.dsp.exec_cmd("~/.config/ml4w-juanjo/scripts/cava-toggle.sh bg")'`.

### Decisiones descartadas (para no rehacerlas)

- **El workspace especial**: la primera versión del modo ventana usaba un `special:cava`. Tapaba la
  pantalla entera — una ventana sola en un workspace propio ocupa todo — y flotarla la hacía aún más
  grande. Se cambió a ventana tilada normal.
- **cava-bg** (AUR): se descartó por desconfianza en un proyecto de 3 meses con 2 votos, y porque el
  widget propio da lo mismo con Quickshell de repos oficiales. Ver `03-roadmap.md` §A-ter.
- **Colores muestreados del vídeo**: se descartó a favor de matugen. Ver el roadmap.

---

## Estructura del repo

```
overlay/                     ← fuente de verdad: solo lo que personalizamos
  waybar/themes/ml4w-glass-juanjo/   theme propio (temps + botón fondo vídeo)
  hypr/hyprsunset.conf               horario de luz nocturna
  hypr/custom.lua                    hook oficial de ML4W: los dos binds de cava
  cava/config                        cava del modo ventana (salida ncurses)
  ml4w-juanjo/cava-bg/cava-raw.conf  cava del modo fondo (salida raw para el QML)
  ml4w-juanjo/quickshell/cavabg/     widget del fondo (franja + colores de matugen)
  ml4w-juanjo/scripts/cava-toggle.sh toggle de ambos modos (tile|bg) + exclusión mutua
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
