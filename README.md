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

## Un solo overlay para varios equipos

Corre en dos máquinas —un **portátil** Optimus (Intel + GTX 1060 Mobile, `eDP-1`, con batería) y
un **sobremesa** AMD con RTX 5070 Ti y dos monitores— y `overlay/` es **byte a byte el mismo en
las dos**. Lo que cambia de hardware se resuelve **al ejecutarse**, no con carpetas por equipo
ni plantillas:

| Qué difiere | Cómo se resuelve |
|---|---|
| Sensor de CPU (`coretemp` ↔ `k10temp`) | `scripts/cputemp.sh` busca el hwmon por **nombre** |
| Dirección PCI y modelo de la GPU | `scripts/gputemp.sh` los saca de `lspci` y de `nvidia-smi` |
| Cuántas pantallas tienen fondo de vídeo | `scripts/livewallpaper.sh` da **un desplegable por monitor**; el 2º se oculta entero si no hay |
| Sin batería en el sobremesa | waybar descarta el módulo solo si no hay ninguna |

Así se mantiene intacta la regla de oro (*el vivo es una copia byte a byte del overlay*) y
`check.sh` puede seguir comparando overlay ↔ vivo sin ningún paso de render.

**Lo que sí es de cada máquina** va en `~/.config/ml4w-juanjo/local.env`, que **no se versiona**
(y que no hace falta crear si valen los valores por defecto):

```bash
# ~/.config/ml4w-juanjo/local.env
LIVE_WALLPAPER_MONITOR=DP-1                    # botón 1; si no, el primer monitor por id
LIVE_WALLPAPER_MONITOR_2=DP-2                  # botón 2; normalmente sobra (lo detecta solo)
LIVE_WALLPAPER_FOLDER=$HOME/Vídeos/hidamari    # carpeta de vídeos del fondo
LIVE_WALLPAPER_INTERVAL=300                    # segundos entre vídeos
```

> El **botón 2** coge por su cuenta el otro monitor conectado, así que `LIVE_WALLPAPER_MONITOR_2`
> solo hace falta con tres pantallas o para forzar un reparto concreto. El orden es por `id` de
> Hyprland y **no** por el foco: con dos pantallas el foco se mueve entre que waybar lee el estado
> y que pulsas, y los dos botones se intercambiarían la identidad.

> ⚠️ **La ruta distingue mayúsculas.** Si el botón dice *"Sin vídeos en …"* teniendo vídeos, casi
> seguro es eso: `Hidamari` y `hidamari` son carpetas distintas. El aviso imprime la ruta exacta
> que buscó — compárala con `ls ~/Vídeos`. Y solo cuenta `*.mp4`, `*.mkv` y `*.webm`.

### Estrenar el overlay en un equipo nuevo

```bash
sudo pacman -S cava mpvpaper       # las dos únicas dependencias que aplicar.sh no instala
git clone … && cd hyprland-dotfiles
./check.sh                         # confirma que la base de ML4W no ha derivado
./aplicar.sh
./check.sh                         # "todo en sync"
```

Y dos cosas a mano después: elegir la variante de decoración **"Juanjo"** en la GUI de ML4W
(*Appearance*) —`aplicar.sh` la deja disponible pero no la fuerza, para no pelear con el
selector— y poner vídeos en la carpeta si se quiere el fondo de vídeo.

---

## Qué incluye (todo desplegado y en producción)

| Personalización | Qué hace | Dónde |
|---|---|---|
| **Waybar: temperaturas** | Temp de CPU y GPU (Optimus: Intel iGPU + NVIDIA dGPU) en la barra | theme propio `ml4w-glass-juanjo` |
| **Waybar: fondo de vídeo** | Un botón por pantalla (`󰕧¹` `󰕧²`) que enciende/apaga un fondo de vídeo (mpvpaper) en **cada monitor por separado**, y que al pasar el ratón **despliega tres controles de esa pantalla**: sonido (exclusivo entre pantallas), rotación automática y saltar al siguiente vídeo | `scripts/livewallpaper.sh` |
| **Luz nocturna (hyprsunset)** | Filtro de luz azul automático por horario **21:00 → 07:00** (4000 K) | `overlay/hypr/hyprsunset.conf` + systemd |
| **Fastfetch: logo rotativo** | Muestra una imagen distinta al azar en cada arranque de terminal | `overlay/fastfetch/` |
| **Visualizador de audio (cava)** | Barras al ritmo, en dos modos excluyentes: ventana (**SUPER+SHIFT+C**) y fondo (**SUPER+ALT+C**) | `overlay/cava/` + `overlay/ml4w-juanjo/` + `overlay/hypr/custom.lua` |
| **Encendido robusto al reanudar** | Evita la pantalla en negro tras suspender: espera a que la sesión esté activa y **cicla** el DPMS con reintentos | `overlay/ml4w-juanjo/scripts/despertar-pantallas.sh` + `overlay/hypr/hypridle.conf` |
| **Control de inactividad** | Botón 󰅶 desplegable en la barra: desactiva por separado el **bloqueo**, el **apagado de pantallas** y la **suspensión** (para dejar algo trabajando solo). Incluye el **vigilante** que reapaga la DP-1 cuando se enciende sola, y **SUPER+SHIFT+D** para despertar las pantallas a ciegas | `overlay/ml4w-juanjo/scripts/idle-guard.sh` + `overlay/hypr/hypridle.conf` + `overlay/hypr/custom.lua` |
| **Salida de audio fija al monitor con altavoces** (sobremesa) | Ancla la tarjeta HDMI de la NVIDIA en el conector del **ASUS MG278 (DP-2)**; sin esto WirePlumber se iba solo al **DP-1**, que es mudo | `overlay/wireplumber/wireplumber.conf.d/51-salida-hdmi-dp2.conf` |

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

## Fondo de vídeo (el desplegable 󰕧 de la barra)

Un **grupo desplegable por pantalla**, independientes: `󰕧¹` y `󰕧²` encienden y apagan su propio
`mpvpaper` en su monitor, y al pasar el ratón despliegan tres controles **de esa pantalla**:

| Icono | Qué hace |
|---|---|
| `󰕾` | **Sonido** del vídeo. Es **exclusivo**: activarlo en una pantalla silencia la otra (dos bandas sonoras a la vez no se entienden). Siempre arranca en silencio. |
| `󰑖` | **Rotación** automática de vídeo cada 5 min. Coloreado = rotando, atenuado = vídeo fijo. Es **pegajosa**: si la apagas, sigue apagada la próxima vez que enciendas el fondo. |
| `󰒭` | **Saltar** ya al siguiente vídeo, sin esperar. Reinicia la cuenta de los 5 min. |

Los tres se **ocultan solos** si ese fondo está apagado: no hay nada que controlar. Con una sola
pantalla, la ranura 2 entera (ancla incluida) desaparece de la barra.

### Cómo se controla mpv sin relanzarlo

Cada instancia se lanza con un **socket IPC** (`-o "input-ipc-server=…"`, camino que el propio man
de `mpvpaper` documenta) en `$XDG_RUNTIME_DIR/mpvpaper-<MONITOR>.sock`, y los clics hablan por ahí
con `socat`. Relanzar `mpvpaper` para cada cambio cortaría el vídeo, perdería la posición y
rebarajaría la lista.

Tres decisiones que **no hay que "simplificar"**:

- **El audio se controla con `mute`, no con `aid`** — y por eso `mpvpaper` arranca con `mute=yes` y
  ya no con `no-audio`. `mute` es estable aunque el vídeo de turno **no tenga pista de audio** y
  sobrevive a los cambios de vídeo; con `aid` el icono mentiría en cuanto tocase un vídeo mudo.
  Coste asumido: mientras el fondo esté encendido, mpv mantiene un stream silenciado en el
  mezclador.
- **`-n 86400` no es la rotación.** El `-n <s>` de `mpvpaper` es un temporizador **interno suyo**,
  no una propiedad de mpv: no se puede parar ni adelantar por IPC. Pero ese mismo flag es el camino
  por el que `mpvpaper` convierte la **carpeta** en una playlist, así que se conserva con un valor
  tan grande que nunca estorba. Quitarlo del todo arriesga quedarse sin lista que rotar
  (`playlist-count` debe dar el número de vídeos, no `1`).
- **La rotación la lleva un bucle propio**, uno por monitor, lanzado desde `start()` y matado en
  `stop()`. No guarda nada en memoria: lee el reloj de `~/.cache/ml4w-juanjo/livewallpaper-ultimo-<MON>`,
  de modo que el botón de saltar reinicia la cuenta sin tener que hablar con él. Si `mpvpaper`
  muere sin pasar por `stop()`, el bucle se entera en un tick y sale solo.

Para pasar de vídeo **no** se usa `playlist-next`: en la última entrada `weak` no hace nada y
`force` puede terminar la reproducción. Se leen `playlist-pos` y `playlist-count` y se salta a
`(pos+1) % count` — determinista y da la vuelta al final de la lista.

### El estado vive en ficheros, no en mpv

`waybar` refresca los ocho módulos a la vez y cada ida y vuelta por el socket cuesta décimas, así
que **ningún `*-status` consulta a mpv**: como los únicos que tocamos el reproductor somos
nosotros, el estado se anota en `~/.cache/ml4w-juanjo/livewallpaper-*-<MONITOR>` y por IPC solo van
los **clics**, donde el retardo no se nota.

---

## Visualizador de audio (cava)

Dos modos, **excluyentes** (encender uno apaga el otro — no tiene sentido tener dos visualizadores
pintando lo mismo):

| Atajo | Modo | Qué es |
|---|---|---|
| **SUPER+SHIFT+C** | **Ventana** | cava en una kitty, **tilada en el workspace actual**. Se mueve/redimensiona como cualquier ventana. |
| **SUPER+ALT+C** | **Fondo** | Franja de barras abajo (≈23 % del alto de la pantalla: 250 px en 1080p, 333 en 1440p), **sobre el vídeo de mpvpaper y debajo de las ventanas**. Widget Quickshell propio. |

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
| `stripRatio` | 250/1080 | Alto de la franja como **fracción del alto del monitor**, no en px: 250 px se calibraron en 1080p y en 1440p se veían bajos. Sale 250 px en 1080p y 333 en 1440p, y cada monitor se dimensiona solo |
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
> `grim -o <monitor> /tmp/x.png` y recortar, o directamente la franja: en 1080p
> `grim -g "0,830 1920x250"`, en 1440p `grim -g "<x>,1190 2560x250"` (la `x` del monitor sale de
> `hyprctl monitors -j`; el sobremesa tiene DP-1 en x=2560). Y `qs` lanzado en segundo plano
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

## Paleta clara tras un update

**Síntoma:** un buen día el escritorio entero amanece en **claro** —waybar, bordes, rofi, GTK,
swaync, btop y la franja de cava— sin haber tocado nada. `./check.sh` dice "todo en sync" porque
nuestros ficheros siguen en su sitio: lo que cambió es la **paleta que genera matugen**.

**Causa (verificada el 2026-07-31).** Es un bug de ML4W que dispara Plasma:

1. `kde-gtk-config` (viene con CachyOS, se activa al arrancar cualquier app KDE) reescribe
   `~/.config/gtk-3.0/settings.ini` en **su** formato y deja el flag de tema oscuro como
   `gtk-application-prefer-dark-theme=`**`true`** en vez de `1`.
2. `run_matugen()` de `ml4w/scripts/ml4w-wallpaper` lo leía con una comparación **numérica**:
   `[ "$theme_pref" -eq 1 ]`. Con `true` eso aborta (*"se esperaba un entero"*), `mode` se queda
   en su valor por defecto `light` y **matugen regenera toda la paleta en claro**.
3. Con `wallpaper-automation` activo, la siguiente rotación de fondo lo propaga a todo.

Es una **incoherencia interna de ML4W**: su propio listener `ml4w/listeners/gtk-theme-switcher.sh`
sí acepta `1/true` y `0/false` explícitamente. Solo `run_matugen` se quedó con el test numérico.

**Arreglo (en el overlay).** `overlay/ml4w/scripts/ml4w-wallpaper` sustituye esa línea por
`case "$theme_pref" in 1 | true) mode="dark" ;; esac`, que acepta ambos formatos. Al ser un
fichero de ML4W lleva baseline y comprobación de 3 estados en `check.sh` (§6b), más un chequeo
de coherencia (§6c) que avisa si la paleta sale clara teniendo el tema oscuro pedido.

**Reportado en upstream** ([ML4W #1765](https://github.com/mylinuxforwork/dotfiles/issues/1765)),
donde [PR #1759](https://github.com/mylinuxforwork/dotfiles/pull/1759) ya lo arregla en origen.
Cuando la mergeen, **este parche sobra y hay que retirarlo** del overlay o `check.sh` avisará de
deriva para siempre — seguimiento en la
[issue #3](https://github.com/juanjocop/hyprland-dotfiles/issues/3), con el comando para saber
cuándo toca y los pasos exactos.

Si te vuelve a pasar (p. ej. antes de re-aplicar tras un update de ML4W), regenerar es:

```bash
~/.config/ml4w/scripts/ml4w-wallpaper "$(cat ~/.cache/ml4w/hyprland-dotfiles/current_wallpaper)"
```

> ⚠️ **El toggle de tema de ML4W sigue roto por la misma causa** y no lo hemos parcheado.
> `ml4w-toggle-theme` busca `=1` con `grep -q`; al encontrar `true` cae al `else` y hace
> `sed 's/=0/=1/'`, que tampoco casa → imprime *"Switched to dark theme"* y **no cambia nada**.
> Mientras el flag valga `true` no se puede pasar a claro desde la GUI. No nos molesta porque
> queremos oscuro siempre; si algún día hace falta, se arregla poniendo el flag a mano a `0`.

### El otro síntoma: iconos de bandeja negros

**La misma escritura de kde-gtk-config** (30 jul, 13:59:51) cambió también
`gtk-icon-theme-name` de **`breeze-dark`** a **`breeze`**. Son la variante oscura y la clara del
mismo set: los trazos pasan de `#fcfcfc` a `#232629`. Sobre la barra oscura, el icono de
`nm-applet` se volvió **negro y casi invisible**.

Es fácil confundirlo con el módulo `network` de waybar, pero **no lo es**: el módulo (el glifo
Font Awesome + `enp8s0`) se ve blanco y correcto. Lo que está negro es el icono de **bandeja**,
que no pinta el CSS de waybar sino el **icon theme de GTK**. Por eso "parece que no está atado
al theme" — es que literalmente no lo está.

**Arreglo:** `aplicar.sh` (§5d) fija `gtk-icon-theme-name=breeze-dark` en `gtk-3.0` y `gtk-4.0`
más `gsettings`, y `check.sh` (§6d) avisa si vuelve a una variante clara.

Dos detalles del arreglo:

- **Se fija solo esa clave, no el fichero entero.** `settings.ini` lleva valores **por máquina**
  (`gtk-xft-dpi`, cursor…), así que un overlay byte a byte rompería el multi-equipo.
- **Es global, no acotado a la barra.** Waybar 0.15 **no** tiene opción `icon-theme` en el módulo
  `tray` (solo la tienen `hyprland-workspaces` y `wlr-taskbar`), así que no hay forma de tocar
  únicamente los iconos de waybar. Como todo el escritorio es oscuro, `breeze-dark` es lo
  coherente de todos modos — y es lo que el equipo ya tenía antes.

> Los iconos de bandeja **no se recolorean solos**: hay que reiniciar la app que los sirve
> (`nm-applet`). Tras `./aplicar.sh`, o cierras sesión, o:
> `pkill -f nm-applet; hyprctl dispatch 'hl.dsp.exec_cmd("nm-applet --indicator")'`
> (lanzado desde un shell suelto se muere con el padre; por eso va vía Hyprland). Al
> re-registrarse aparece al final de la bandeja; en el siguiente login recupera su orden.

---

## Pantalla en negro tras suspender (sobremesa)

Han sido **dos fallos distintos con el mismo síntoma**, y confundirlos costó una semana. Si vuelve
el negro, la primera pregunta es siempre **`coredumpctl list`**: dice cuál de los dos es.

**1. Hyprland MUERE → era aquamarine 0.13.0.** SIGSEGV en `SDRMConnector::releaseCommitBuffers`
al caducar un weak pointer. Arreglado en upstream por `c0bd9ed`, publicado en **aquamarine
0.14.0**. Ya no debería volver; se comprueba con:

```bash
grep -qa releaseStashedCommit /usr/lib/libaquamarine.so && echo "con el bug" || echo "arreglado"
```

**2. Hyprland SIGUE VIVO → es lo que arregla este overlay.** No hay coredump, los monitores se
detectan bien y aun así la pantalla está negra. El rastro está en el log de la sesión:

```bash
grep "enabledState changed" /run/user/1000/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log
```

Si solo hay `true -> false` y ningún `false -> true`, es este: los outputs se quedaron
deshabilitados y **nadie los volvió a encender**.

La línea de serie de ML4W dispara el encendido **una vez y a ciegas**, y aquí eso no basta por
dos motivos:

- **Carrera.** `after_sleep_cmd` salta con `PrepareForSleep(false)`, cuando la sesión de logind
  aún no se ha reactivado. aquamarine contesta `Session inactive` y el encendido se pierde.
- **Estado que miente.** Estos monitores **tiran el enlace DisplayPort a los ~6 s** de apagarse
  (verificado: DP-1 desaparece de `hyprctl monitors` y reaparece solo). Al reconectar se recrean
  como monitor nuevo con `dpms=true`, mientras el conector sigue deshabilitado por debajo →
  `dpms enable` se convierte en un **no-op**.
- **Victoria falsa** (visto el 2026-09-09, 11:25). El mismo tirón de enlace puede caer **justo
  después** de encender: la DP-1 se enciende, tira el enlace y **desaparece** de la lista de
  monitores. La comprobación de éxito de entonces era "¿están encendidas todas las que veo?", que
  con la DP-1 ausente sale **verdadera de forma vacía**. El log lo canta comparado con cualquier
  reanudación buena:

  ```
  ciclo 1 → DP-2=1 DP-1=1      ← bien
  ciclo 1 → DP-2=1             ← el fallo: la DP-1 no está, y aun así "OK en el ciclo 1"
  ```

  Peor aún: al darlo por bueno escribía el `$SELLO`, y el sello **anula la segunda oportunidad**
  del `on-resume`. La DP-1 se quedó negra.

Por eso `despertar-pantallas.sh` **espera** a que la sesión esté activa y luego **cicla** el DPMS
(apagar + encender) con reintentos, en vez de solo encender. El ciclo es incondicional a
propósito: consultar el estado y decidir "ya están bien" sería caer justo en el segundo motivo.

Y por eso el éxito se mide contra una **lista concreta** de monitores exigidos, no contra los que
haya en pantalla en ese instante. Dos reglas que no hay que re-derivar:

- **Siempre `hyprctl monitors all`, nunca `hyprctl monitors` a secas.** La forma corta **oculta
  los conectores deshabilitados**, que es exactamente el estado del fallo. Preguntar por la lista
  corta es preguntarle al problema si hay problema.
- **Un monitor ausente nunca cuenta como encendido.** La lista se siembra con los monitores
  presentes al empezar más los del último encendido bueno (`despertar-pantallas.monitores`), solo
  crece durante los ciclos, y el script **sondea hasta 8 s** a que el ausente rehaga su enlace DP.
  Lo que de verdad ya no está (cable fuera) se poda al final, con su línea en el log, para no
  arrastrar un `hyprctl reload` en cada reanudación.

Deja rastro en `~/.cache/ml4w-juanjo/despertar-pantallas.log`, que es lo primero que hay que
mirar si el negro reaparece. Ahí, `DP-1=AUSENTE` significa que no está en la lista y `DP-1=!1`
que está pero con el conector deshabilitado.

---

## Control de inactividad (el botón 󰅶 de la barra)

Para dejar algo trabajando solo —una IA en una terminal, una compilación larga— sin que el equipo
se pare. Un grupo desplegable en la barra con tres interruptores independientes:

| Interruptor | Desactiva | ¿Detiene lo que esté trabajando? |
|---|---|---|
| 󰌾 **Bloqueo** | el `loginctl lock-session` de los 10 min | **No** — solo tapa la pantalla |
| 󰍹 **Pantallas** | el apagado de pantallas de los 11 min | **No** — solo apaga la salida de vídeo |
| 󰤄 **Suspensión** | el `systemctl suspend` de los 30 min | **Sí**: suspender **congela todos los procesos** |

Los **tres interruptores** siguen la convención del resto de botones de la barra (fondo de vídeo,
luz nocturna): **coloreado = esa función funciona**, atenuado = la has desactivado tú.

El **ancla** (󰅶) resume el estado y con un clic los alterna todos a la vez. **Va al revés que sus
hijos, a propósito**: su icono es un **café**, y un café no representa "el bloqueo funciona" sino
**cafeína**. Se lee solo, y destaca justo el estado del que conviene no olvidarse:

| Ancla | Significado |
|---|---|
| `@primary` (coloreada) | **Café ON**: los tres desactivados, el equipo no hará nada solo |
| `@secondary` | Café a medias: has desactivado **alguno** de los tres |
| Atenuada | Café OFF: todo normal — se bloqueará, apagará pantallas y suspenderá |

Los tooltips lo dicen con todas las letras (*"Café ON"* / *"Café OFF"*) por si la doble lectura
despista.

**Lo que de verdad hace falta desactivar es la suspensión.** Bloquear la sesión o apagar las
pantallas no para nada; solo molestan si quieres vigilar el progreso de un vistazo. Ojo con
confundir bloquear con **cerrar sesión**: cerrar sesión sí mata los procesos de la sesión.

### Por qué un guardián y no un inhibidor

Nada de esto se puede hacer en caliente con hypridle (verificado, no re-derivar):

- **hypridle 0.1.8 no tiene IPC.** No hay socket de control: no se puede activar ni desactivar un
  listener sin reescribir el config y relanzar el daemon — y **relanzarlo reinicia el contador de
  inactividad**. `ignore_inhibit` existe, pero es estático y por listener.
- **Los inhibidores estándar son globales.** `systemd-inhibit --what=idle` frena todos los
  listeners de golpe: justo la granularidad todo-o-nada que queremos evitar.
- **Reescribir el `hypridle.conf` vivo** rompería la igualdad byte a byte overlay ↔ vivo de
  `check.sh` (§6e).

Como el overlay ya es dueño de `hypridle.conf`, la solución es la **indirección**: los `on-timeout`
llaman a `idle-guard.sh`, que **en el momento del disparo** mira una bandera y decide si ejecuta la
acción o la ignora. Config estático, daemon intacto, granularidad libre.

Las banderas son ficheros vacíos en `$XDG_RUNTIME_DIR/ml4w-juanjo/inactividad/` — **tmpfs a
propósito: la inhibición se limpia sola al cerrar sesión o reiniciar.** Nada de `~/.cache`:
dejarse el equipo sin suspender "para siempre" sin recordarlo es justo el fallo que no queremos.
`check.sh` (§6g) recuerda con un `ℹ` qué hay desactivado, sin tratarlo como error.

### El parpadeo que hay que evitar

El `on-resume` del listener de 11 min salta al mover el ratón **aunque las pantallas nunca se
hayan apagado**, y `despertar-pantallas.sh` **cicla el DPMS de forma incondicional** (por diseño,
ver su cabecera). Sin más, desactivar el apagado de pantallas habría provocado un **parpadeo cada
vez que vuelves al equipo**. Por eso el guardián deja una marca `pantallas-apagadas` al apagar y
solo llama a `despertar-pantallas.sh` si esa marca existe. El `$SELLO` de aquel script no cubre
este caso: deduplica dos encendidos seguidos, no un encendido sin apagado previo.

### La pantalla que se encendía sola (el vigilante)

`dpms disable` apaga las dos, pero **la DP-1 (KTC H27E6, la de 240 Hz) se volvía a encender sola a
los ~8 s y se quedaba encendida toda la noche**. Es el **mismo tirón de enlace DisplayPort** de la
sección anterior, visto desde el otro lado: el monitor tira el enlace al quedarse sin señal y, al
reasomar, Hyprland lo trata como un monitor **nuevo** y le hace **modeset** — y un modeset enciende
el panel. Hyprland no recuerda que estábamos en modo "apagadas por inactividad", así que nadie
deshace ese encendido. La DP-2 (ASUS MG278) no lo hace: es firmware del KTC. En el log de la sesión:

```
drm: Connector DP-1 disconnected  →  Disabling output DP-1  →  enabledState true -> false
drm: Connector DP-1 connected     →  Connecting connector DP-1, CRTC ID 200
drm: Modesetting DP-1 with 2560x1440@240.00Hz          ← aquí se enciende
```

Se veía doble, porque el ciclo incondicional del apagado sumaba lo suyo: la 1 encendida se apagaba
y luego se encendían las dos. Arreglando la causa desaparecen los dos síntomas.

`idle-guard.sh` lanza un **vigilante** que vive solo mientras dura el apagado: sondea `hyprctl
monitors` cada 2 s y **reaplica el apagado** si alguna pantalla aparece encendida. Se sondea en vez
de escuchar el socket2 de Hyprland porque el bucle solo vive durante el apagado y así no hacen
falta `socat` ni `nc -U`, que no están garantizados en las dos máquinas.

**Tres frenos, porque un vigilante que se equivoca deja el equipo a oscuras:**

1. **Máximo 3 reaplicaciones, y al rendirse DESHACE.** Si un monitor tirase el enlace *cada* vez que
   lo apagamos esto sería un ping-pong de parpadeos; tras 3 intentos se rinde, y entonces **borra la
   marca y llama a `despertar-pantallas.sh` para encenderlo todo**, con el motivo en el log.
   *Medido en 7 ciclos reales: normalmente `reaplico apagado (1/3)` y nunca una segunda vez.*
2. **Muere solo** si desaparece la marca o si `hyprctl` no contesta —hereda
   `HYPRLAND_INSTANCE_SIGNATURE`, así que **solo puede tocar su propia sesión** de Hyprland—. A las
   8 h deja de reaplicar el apagado, pero **sigue vivo mientras viva el detector de vuelta** (ver
   [más abajo](#el-aviso-de-vuelta-que-se-perdía-hypridle208)), que es suyo.
3. **`despertar-pantallas.sh` lo mata nada más empezar.** Es lo crítico: al volver de una
   suspensión las pantallas se encienden con la marca de apagado **todavía puesta**, y un vigilante
   vivo desharía ese encendido → el fondo negro de la issue #1 otra vez. Quien manda al encender es
   `despertar-pantallas.sh`.

Comprobación de que funciona, en `~/.cache/ml4w-juanjo/despertar-pantallas.log`: cada reanudación
registraba `estado: DP-2=0 DP-1=1` (la 1 encendida sola) y ahora registra `DP-2=0 DP-1=0`.

> El fondo del asunto es firmware del KTC. Si algún día su OSD gana un *DP Deep Sleep* / *Auto
> Standby*, ese sería el arreglo de raíz y el vigilante sobraría.

#### Por qué rendirse tiene que ser *deshacer* (2026-08-06)

El freno 1 decía que rendirse dejaba «el comportamiento de antes, ni mejor ni peor». **Era falso**, y
costó una DP-2 negra durante 45 min. Rendirse dejaba la **DP-1 encendida** (se reenciende sola) y la
**DP-2 apagada** (esa no), y con la marca puesta lo único capaz de reencenderla era el `on-resume` de
hypridle. Aquel día **no llegó nunca**.

La evidencia, en el `hyprland.log` de la sesión:

- Un **único** `DP-2 enabledState true -> false` (el apagado legítimo), y 2.500 líneas después nadie
  lo ha deshecho. Mientras, `Modesetting DP-1` **diez veces**: el ping-pong.
- **Clics de ratón** (eventos libinput) en pleno tramo, con la DP-2 negra → el usuario estaba activo
  y aun así `pantallas-on` no se ejecutó ni una vez (ningún log de hoy en los dos ficheros).
- Dos `pantallas-off` (10:10 y 10:37) **sin un solo `on-resume` entre medias**, cosa que hypridle no
  debería hacer.
- 470 `atomic drm request: failed to commit: Device or resource busy` concentrados exactamente en la
  franja del ping-pong.

**La sospecha de entonces era equivocada:** se culpó a la reconexión de la DP-1, que recrearía la
notificación de idle. Pero esa reconexión ocurre en *todos* los apagados, también en los que
despiertan bien, y las notificaciones de idle de Hyprland no dependen de los monitores. La causa
real apareció el 2026-09-13: ver [El aviso de vuelta que se perdía](#el-aviso-de-vuelta-que-se-perdía-hypridle208).

**La moraleja de diseño sigue en pie:** no se puede confiar en que el aviso de vuelta llegue, así que
el vigilante **no puede irse dejando pantallas muertas**. Si el apagado no se puede sostener, lo
único coherente es encenderlo todo.

Y por si aun así te quedas a oscuras (ahí el botón de la barra no sirve, no se ve), hay una **salida
de emergencia a ciegas**. Desde el detector de vuelta no debería hacer falta; queda como red por
debajo de la red:

| Tecla | Qué hace |
|---|---|
| **SUPER+SHIFT+D** | Despierta las pantallas a mano. Es la misma acción que el `on-resume` de hypridle: para al vigilante (y al detector), borra la marca y cicla el DPMS con reintentos. Inofensiva con las pantallas ya encendidas (sin marca no cicla nada). |

### El aviso de vuelta que se perdía (hypridle#208)

**2026-09-13.** Las **dos** pantallas negras al volver al equipo, y hubo que entrar por un TTY.
Hyprland estaba sano (sin coredump, y su log DRM idéntico al de los seis apagados anteriores, que sí
despertaron), y el vigilante **seguía vivo media hora después**: `pantallas-on` no llegó a
ejecutarse nunca. No es ninguno de los fallos de la [pantalla en negro tras
suspender](#pantalla-en-negro-tras-suspender-sobremesa): aquí no hubo suspensión.

**La causa está en el código de hypridle** (0.1.8, idéntico en `main`; bug abierto
[hyprwm/hypridle#208](https://github.com/hyprwm/hypridle/issues/208)):

1. Cuando el contador de inhibidores de hypridle (DBus `org.freedesktop.ScreenSaver` o el `idle` de
   logind) **baja a 0 estando ya inactivo**, `CHypridle::onInhibit()` **destruye y recrea** todas sus
   notificaciones de idle.
2. Hyprland solo manda `resumed` a una notificación que había llegado a `idled`
   (`CExtIdleNotification::reset()`). La recreada aún no ha llegado, así que la actividad real **no la
   despierta**: el `on-resume` del listener de 11 min no llega nunca.
3. Si tras la recreación pasan otros 11 min sin tocar nada, **vuelve a saltar `pantallas-off`**. Es la
   firma exacta del 2026-08-06: dos apagados seguidos sin un `on-resume` entre medias.

Quien sube y baja ese contador es cualquier navegador con vídeo o audio (Wake Lock), así que pasa sin
hacer nada raro. Y el vigilante no lo salvaba: con una sola reencendida de la DP-1 no llega a
rendirse, así que nada iba a encender las pantallas en 8 h.

**Reproducido en el sobremesa**, con dos hypridle de prueba a la vez (listener de 3 s) y la actividad
generada por un teclado virtual (`zwp_virtual_keyboard_v1`, que llega a Hyprland aunque la sesión esté
en otro TTY):

| Momento | Hypridle que obedece inhibidores (como el de la sesión) | El detector (`hypridle-vuelta.conf` real) |
|---|---|---|
| Tecla de control | `resumed` | `resumed` |
| Tecla tras `systemd-inhibit --what=idle sleep 1` | **nada** | `resumed` |
| 3 s después | **`idled` otra vez, sin `resumed`** | — |

**El arreglo: un detector de vuelta.** Mientras dura el apagado, el vigilante lanza un **segundo
hypridle** con config propio (`~/.config/ml4w-juanjo/hypridle-vuelta.conf`) que **ignora todos los
inhibidores**: no se suscribe a ninguno, así que nunca pasa por `onInhibit()`. Tiene un único listener
de 1 s cuyo `on-resume` es `idle-guard.sh accion pantallas-on detector`. Cubre ratón y teclado, no
sondea nada, y el hypridle de la sesión queda intacto.

Decisiones que no hay que rehacer:

- **Descartado ignorar los inhibidores en el hypridle de la sesión** (`ignore_dbus_inhibit` +
  `ignore_systemd_inhibit`). Quita la causa en dos líneas, pero entonces un vídeo ya no impediría que
  se apagaran las pantallas.
- **`on-timeout = true` no sobra.** Con `on-timeout` vacío hypridle da el listener por no disparado y
  se salta también el `on-resume`.
- **Al volver llegan los dos avisos casi a la vez**, así que `pantallas-on` *reclama* la marca con un
  `rm` sin `-f`, que es atómico: solo el primero cicla el DPMS. El log dice quién pidió el encendido
  (`encendido pedido por: hypridle | detector | atajo`) y el que llega segundo queda como `sin marca
  de apagado (…)`. **Si en una vuelta solo aparece `detector`, acabas de ver el bug en acción.**
- **`despertar-pantallas.sh` toma un `flock`.** Con el detector ya son cuatro los caminos que pueden
  llegar a la vez, y dos ciclos de DPMS solapados se pisan.
- **El vigilante es el dueño del detector**: se lo lleva al terminar por cualquier vía, también por
  SIGTERM (de ahí su `sleep & wait`, para que la señal se atienda al instante).
- **`aplicar.sh` y `check.sh` usan `pgrep`/`pkill -fx hypridle`** (línea de órdenes exacta), para no
  confundir al hypridle de la sesión con el detector.
- **`aplicar.sh` instala los dos scripts con `mv`, no con `cp` encima.** El vigilante es un bash que
  puede llevar horas ejecutando `idle-guard.sh`, y bash lee su script a trozos: sobrescribir el mismo
  inodo le haría ejecutar un fragmento del script nuevo al terminar.

> Si hypridle arregla #208 upstream, el detector sobraría — pero no estorba.

### Dos comportamientos que no son bugs

1. **hypridle no reintenta un timeout ya vencido.** Si a los 30 min se ignora la suspensión y
   luego reactivas el interruptor sin tocar el equipo, no se suspenderá hasta el siguiente ciclo
   (mover ratón/teclado y volver a estar 30 min inactivo). Es el comportamiento seguro.
2. **Las tres omisiones quedan en el log**, `~/.cache/ml4w-juanjo/idle-guard.log`. Es lo que
   contesta a "¿por qué no se ha suspendido?".

> ⚠️ **No uses el botón `custom/hypridle` de ML4W** (el que sale dentro de `group/tools`). Hace
> `killall hypridle`, o sea se lleva por delante también el `after_sleep_cmd` que arregla la
> pantalla en negro al reanudar. No se puede quitar de la barra sin editar el `modules.json`
> compartido de ML4W, cosa que este overlay no hace por principio.

---

## El sonido se iba solo al monitor mudo (sobremesa)

**Síntoma.** Cada cierto tiempo el audio deja de salir por los altavoces del **ASUS MG278**.
La barra sigue diciendo que hay salida HDMI y `pactl` la da por `RUNNING`, pero no se oye nada.

**Causa.** La tarjeta de audio de la RTX 5070 Ti (`GB203`) expone **un puerto por conector**, y
cada puerto vive en un **perfil distinto** — solo uno puede estar activo:

| Perfil | Puerto | Monitor | Prioridad | ¿Altavoces? |
|---|---|---|---|---|
| `output:hdmi-stereo` | `hdmi-output-0` | DP-1 · KTC H27E6 | **5900** | **no** |
| `output:hdmi-stereo-extra1` | `hdmi-output-1` | DP-2 · ASUS MG278 | 5700 | sí |

WirePlumber elige perfil en **tres pasos encadenados**, y se queda con el primero que resuelva:

1. `device/find-stored-profile` — el de `~/.local/state/wireplumber/default-profile`… **pero solo
   si en ese momento está `available`**.
2. `device/find-preferred-profile` — el que digan las reglas de `device.profile.priority.rules`.
3. `device/find-best-profile` — el de **mayor prioridad** disponible.

Si el ASUS no está listo cuando se evalúa —arranque en frío, o la **caída de enlace DP** de estos
monitores al dormirse (la misma de [issue #1](#pantalla-en-negro-tras-suspender-sobremesa))— el
paso 1 se salta y manda el paso 3, que por prioridad coge el **DP-1 mudo**. Y ahí se queda.
Por eso **fijar la salida a mano no aguanta**: el fichero de estado no es la última palabra.

**Arreglo.** Rellenar el paso 2, que hasta ahora estaba vacío:
`overlay/wireplumber/wireplumber.conf.d/51-salida-hdmi-dp2.conf` pide `output:hdmi-stereo-extra1`
**por nombre**, sin mirar disponibilidad → gana siempre al paso 3, pase lo que pase con el DP.

Verificado borrando la entrada del fichero de estado y reiniciando WirePlumber: elige `extra1`
igualmente, en vez del `hdmi-stereo` de mayor prioridad. `check.sh` §6h avisa si algún día no es así.

**Multi-equipo (verificado, no supuesto).** La regla casa por `device.product.name = "GB203 …"`,
sin comodines, no por ruta PCI (que cambia de máquina y no distingue nada más). En el **portátil**
—GP106, y los altavoces colgando de la tarjeta **Intel HDA analógica**— no casa nada, así que el
fichero es un **no-op**: se probó desplegando esta misma regla con un producto inexistente y
WirePlumber arranca igual, todas las tarjetas conservan su perfil y el sink por defecto no se mueve.
Por eso el fichero se despliega en **los dos equipos** (mismo overlay en ambos), sin condicionar
por hostname.

Aun así `aplicar.sh` lleva **red de seguridad**: los `.conf` de `wireplumber.conf.d/` se fusionan
en la config global, y un fichero que a esa versión de WirePlumber no le guste dejaría el equipo
**sin audio ninguno**. Si tras desplegarlo el daemon no arranca, `aplicar.sh` lo retira, reinicia
WirePlumber y avisa.

**Detalles que ahorran tiempo si vuelve:**

- **`pactl set-card-profile` sí persiste, pero no basta.** Guarda en el fichero de estado, y ese
  fichero lo ignora WirePlumber justo en el caso que rompe (perfil no disponible al evaluar).
- **La selección automática NO reescribe el estado.** `device/apply-profile` fija el perfil sin
  `save`, así que el hook de guardado no salta. Si el fichero de estado dice algo raro, lo puso
  una acción de usuario (`pactl`, un mezclador gráfico…), no el fallback.
- **Cambiar de perfil mueve los streams a otro sink.** Tras el cambio, lo que estuviera sonando
  (los `mpv` del fondo de vídeo, por ejemplo) aparece en la salida por defecto. Se devuelven con
  `pactl move-sink-input <id> <sink>`.
- **La salida por defecto es cosa aparte.** Aquí solo se elige *qué conector* usa la tarjeta HDMI;
  cuál es el sink por defecto (cascos HyperX vs. monitor) se sigue cambiando como siempre.

---

## Claude Desktop pedía login en cada arranque

**Síntoma.** Abrir la app de Claude y encontrarse siempre la pantalla de login, por mucho que se
hubiera entrado la vez anterior.

**Causa.** Las apps Electron guardan sus credenciales con `safeStorage`, que necesita una clave
maestra del llavero del sistema. Chromium elige el backend del llavero mirando
`$XDG_CURRENT_DESKTOP`: `KDE`→kwallet, `GNOME`/`Unity`/…→libsecret, y **cualquier otra cosa→
`basic_text`**. `Hyprland` cae en "cualquier otra cosa". Con `basic_text` Electron devuelve
`isEncryptionAvailable=false` y la app directamente **no guarda el token**. Lo dice ella misma en
`~/.config/Claude/logs/main.log`:

```
[safeStorage] isEncryptionAvailable=false on linux at startup (backend=basic_text)
[oauth-v2] safeStorage not available, tokens will not persist
```

Que aparezca de vez en cuando un `[safeStorage] kwalletd pre-flight (kwalletd6): has-wallet` y esa
vez sí funcione es la parte que despista: la app intenta detectar kwallet por su cuenta, pero
depende de que `kwalletd6` esté ya levantado en ese instante, así que unos arranques cuelan y
otros no. **No es intermitencia del llavero, es una carrera.**

**Arreglo (dos piezas, y solo una de ellas es la que cierra el caso).**

1. **`--password-store=gnome-libsecret` en el lanzador** — *esta es la que lo arregla*. Se le dice
   el backend a mano y se acabó la adivinación. Va por `gnome-libsecret`
   (`org.freedesktop.secrets` → `ksecretd`, que CachyOS ya desbloquea en el login vía
   `ksecretd --pam-login`) y **no** por `kwallet6`, porque el wallet de `kwalletd6` arranca
   **cerrado** y pediría contraseña. `aplicar.sh` §8d **regenera** el `.desktop` en
   `~/.local/share/applications/` a partir del del paquete en cada pase, en vez de versionar una
   copia: así una actualización de `claude-desktop` no nos deja un lanzador viejo, y `~/.local/share`
   gana sobre `/usr/share`.
2. **El portal Secret mapeado a kwallet** (`overlay/xdg-desktop-portal/hyprland-portals.conf`) —
   esta **no** arregla el login. Verificado: con el portal puesto y sin el flag, la app seguía en
   `basic_text`, porque `safeStorage` va por el os_crypt **síncrono**, que ni mira el portal. Lo
   que sí arregla es el os_crypt **asíncrono**, por donde Chromium cifra las **cookies**: en
   Hyprland la interfaz `org.freedesktop.portal.Secret` no la servía nadie (`kwallet.portal` viene
   con `UseIn=kde` y `hyprland-portals.conf` no lo mapea), así que las cookies caían al esquema
   `v10`, ofuscación con clave fija. Se queda porque beneficia a **toda** app Chromium/Electron de
   la máquina. Se comprueba en `~/.config/Claude/Local State`:
   `os_crypt.portal.prev_init_success` pasa de `false` a `true`.

Cuidado con el fichero de portales: **xdg-desktop-portal no fusiona configs**, usa el primero que
encuentra y `~/.config` gana sobre `/usr/share` → hay que repetir el `default=hyprland;gtk` del
sistema o se pierden captura de pantalla, file chooser, etc.

**Cómo se comprueba.** `check.sh` §6i mira dos cosas: que el lanzador lleve el `--password-store`
y que en el **último** arranque de la app (desde su última línea `Starting app`) no aparezca
`isEncryptionAvailable=false`. Acotar al último arranque es importante: la app solo escribe esa
línea cuando falla, así que buscarla en todo el log daría un falso positivo con cualquier arranque
viejo y roto.

**Después de aplicarlo hay que entrar una vez más** — el token que hubiera guardado en claro no se
puede releer ya cifrado (`[oauth] no persisted token cache found`). A partir de ahí, aguanta.

---

## Estructura del repo

```
overlay/                     ← fuente de verdad: solo lo que personalizamos
  waybar/themes/ml4w-glass-juanjo/   theme propio (temps + botón fondo vídeo)
  hypr/hyprsunset.conf               horario de luz nocturna
  hypr/custom.lua                    hook oficial de ML4W: binds de cava + rescate de pantallas
  cava/config                        cava del modo ventana (salida ncurses)
  ml4w-juanjo/cava-bg/cava-raw.conf  cava del modo fondo (salida raw para el QML)
  ml4w-juanjo/quickshell/cavabg/     widget del fondo (franja + colores de matugen)
  ml4w-juanjo/scripts/cava-toggle.sh toggle de ambos modos (tile|bg) + exclusión mutua
  ml4w-juanjo/scripts/despertar-pantallas.sh  encendido robusto de pantallas al reanudar
  ml4w-juanjo/scripts/idle-guard.sh  guardián: decide si bloquear/apagar/suspender o ignorarlo
                                     + vigilante: la DP-1 se reenciende sola y hay que reapagarla
                                     (y si no puede sostener el apagado, lo deshace: nunca deja
                                      una pantalla muerta esperando un on-resume que puede faltar)
  hypr/hypridle.conf                 igual que la de ML4W salvo el encendido robusto y el guardián
  fastfetch/config.jsonc             config con el glob del logo
  fastfetch/logos/*.png              conjunto de logos para la rotación
  ml4w/scripts/ml4w-toggle-hyprsunset  shim: delega el toggle en nightlight.sh
  ml4w/scripts/ml4w-wallpaper          parche: matugen en oscuro aunque el flag diga `true`
  wireplumber/wireplumber.conf.d/    regla que fija la salida HDMI al monitor con altavoces
  xdg-desktop-portal/hyprland-portals.conf  portal Secret → kwallet (cifrado de cookies)
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
