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
| Qué monitor usa el fondo de vídeo | `scripts/livewallpaper.sh` toma el monitor **enfocado** |
| Sin batería en el sobremesa | waybar descarta el módulo solo si no hay ninguna |

Así se mantiene intacta la regla de oro (*el vivo es una copia byte a byte del overlay*) y
`check.sh` puede seguir comparando overlay ↔ vivo sin ningún paso de render.

**Lo que sí es de cada máquina** va en `~/.config/ml4w-juanjo/local.env`, que **no se versiona**
(y que no hace falta crear si valen los valores por defecto):

```bash
# ~/.config/ml4w-juanjo/local.env
LIVE_WALLPAPER_MONITOR=DP-1                    # si no, el monitor enfocado
LIVE_WALLPAPER_FOLDER=$HOME/Vídeos/hidamari    # carpeta de vídeos del fondo
LIVE_WALLPAPER_INTERVAL=300                    # segundos entre vídeos
```

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
| **Waybar: botón fondo de vídeo** | Enciende/apaga un fondo de vídeo (mpvpaper) desde un botón de la barra | `scripts/livewallpaper.sh` |
| **Luz nocturna (hyprsunset)** | Filtro de luz azul automático por horario **21:00 → 07:00** (4000 K) | `overlay/hypr/hyprsunset.conf` + systemd |
| **Fastfetch: logo rotativo** | Muestra una imagen distinta al azar en cada arranque de terminal | `overlay/fastfetch/` |
| **Visualizador de audio (cava)** | Barras al ritmo, en dos modos excluyentes: ventana (**SUPER+SHIFT+C**) y fondo (**SUPER+ALT+C**) | `overlay/cava/` + `overlay/ml4w-juanjo/` + `overlay/hypr/custom.lua` |
| **Encendido robusto al reanudar** | Evita la pantalla en negro tras suspender: espera a que la sesión esté activa y **cicla** el DPMS con reintentos | `overlay/ml4w-juanjo/scripts/despertar-pantallas.sh` + `overlay/hypr/hypridle.conf` |
| **Control de inactividad** | Botón 󰅶 desplegable en la barra: desactiva por separado el **bloqueo**, el **apagado de pantallas** y la **suspensión** (para dejar algo trabajando solo) | `overlay/ml4w-juanjo/scripts/idle-guard.sh` + `overlay/hypr/hypridle.conf` |

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

Por eso `despertar-pantallas.sh` **espera** a que la sesión esté activa y luego **cicla** el DPMS
(apagar + encender) con reintentos, en vez de solo encender. El ciclo es incondicional a
propósito: consultar el estado y decidir "ya están bien" sería caer justo en el segundo motivo.

Deja rastro en `~/.cache/ml4w-juanjo/despertar-pantallas.log`, que es lo primero que hay que
mirar si el negro reaparece.

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
  ml4w-juanjo/scripts/despertar-pantallas.sh  encendido robusto de pantallas al reanudar
  ml4w-juanjo/scripts/idle-guard.sh  guardián: decide si bloquear/apagar/suspender o ignorarlo
  hypr/hypridle.conf                 igual que la de ML4W salvo el encendido robusto y el guardián
  fastfetch/config.jsonc             config con el glob del logo
  fastfetch/logos/*.png              conjunto de logos para la rotación
  ml4w/scripts/ml4w-toggle-hyprsunset  shim: delega el toggle en nightlight.sh
  ml4w/scripts/ml4w-wallpaper          parche: matugen en oscuro aunque el flag diga `true`
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
