# 00 — Contexto y hardware (datos verificados)

> Todo lo de aquí está comprobado en los equipos reales (2026-07). No hace falta redescubrirlo.

## Dos equipos, un solo overlay

El overlay corre en **dos máquinas**, y `overlay/` es **byte a byte el mismo** en ambas: lo que
cambia de una a otra se resuelve **en tiempo de ejecución** (los scripts detectan el hardware),
no con carpetas por equipo ni plantillas. Así `check.sh` puede seguir comparando overlay ↔ vivo
directamente, que es la regla de oro del repo.

| | **Portátil** (equipo original) | **Sobremesa** `cachyos-equipaso` (verificado 2026-07-22) |
|---|---|---|
| Chasis | Portátil Optimus | Gigabyte B650E AORUS ELITE X AX ICE |
| CPU / sensor | Intel 6 núcleos → `coretemp` | AMD Ryzen (Granite Ridge) → **`k10temp`**, `temp1_label=Tctl` |
| iGPU | Intel UHD 630 | AMD Radeon integrada (`amdgpu`) |
| GPU NVIDIA | GTX 1060 Mobile (GP106M), **duerme en reposo** | **RTX 5070 Ti** (GB203), siempre `active` (mueve las pantallas) |
| Dirección PCI de la NVIDIA | `0000:01:00.0` | `0000:01:00.0` (coincide, pero **no se asume**: se resuelve con `lspci`) |
| Batería | sí | **no** — en `power_supply` solo `hidpp_battery_0` (ratón Logitech, `scope=Device`) |
| Pantallas | `eDP-1` | `DP-1` 2560x1440@240 (x=2560) y `DP-2` 2560x1440@144 (x=0) |
| Hyprland | 0.55.4 | 0.56.0 |

**La base de ML4W es idéntica en los dos** (comprobado con `diff` sobre los 5 ficheros que
vigila `check.sh`): cero deriva, el overlay entra limpio en ambos.

Lo específico de cada equipo (qué monitor usa el fondo de vídeo, dónde están los vídeos) vive
en **`~/.config/ml4w-juanjo/local.env`**, que **no se versiona**.

## Hardware relevante (portátil)

- Portátil **Optimus** (gráfica híbrida):
  - iGPU: **Intel UHD 630** (CoffeeLake-H GT2).
  - dGPU: **NVIDIA GeForce GTX 1060 Mobile** (GP106M).
- CPU: 6 núcleos (aparecen Core 0–5 en `sensors`).

## Sensores (comandos verificados)

### CPU — `coretemp` (Intel) / `k10temp` (AMD)

⚠️ **La ruta del sensor es lo que más difiere entre los dos equipos**, por eso ya no se cablea:
`scripts/cputemp.sh` recorre `/sys/class/hwmon/*/name` y toma el primero que case `k10temp` o
`coretemp`. Buscar por **nombre** resuelve de paso que `hwmonN` **no es estable entre
arranques** (el motivo original de usar `hwmon-path-abs`). En ambos chips el sensor bueno es
`temp1_input`.

| Equipo | `name` | Ruta estable | `temp1_input` es |
|---|---|---|---|
| Portátil | `coretemp` | `/sys/devices/platform/coretemp.0/hwmon` | `Package id 0` |
| Sobremesa | `k10temp` | `/sys/devices/pci0000:00/0000:00:18.3/hwmon` | `Tctl` |

(Se dejan las rutas anotadas como referencia, pero **el script no las usa**.)

### GPU — NVIDIA
- `nvidia-smi` disponible y la dGPU responde (drivers propietarios activos).
- Comando para temperatura:
  ```
  nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits
  ```
  Devuelve un entero (ej. `53`).
- Uso/VRAM (para el roadmap): `--query-gpu=utilization.gpu,memory.used,memory.total`.
- `scripts/gputemp.sh` pide **nombre y temperatura en la misma llamada**
  (`--query-gpu=name,temperature.gpu`) para que el tooltip diga la tarjeta real de cada equipo
  sin coste extra, y resuelve la dirección PCI con
  `lspci -D -d 10de: -n` filtrando la clase `0300` (VGA) o `0302` (3D controller).
- La puerta anti-despertar sigue siendo `power/runtime_status`: **solo se llama a `nvidia-smi`
  si NO está dormida**. En el sobremesa siempre está `active`, así que no cambia nada; en el
  portátil sigue sin despertar la dGPU.

### La dGPU idlea a ~3.47 W y la mantiene despierta SDDM (verificado 2026-07)

Dato para no sacar conclusiones falsas al medir consumo de cualquier cosa:

- La NVIDIA aparece siempre `runtime_status: active` con `0 %` de uso y **~3.47 W**, incluso sin
  nada gráfico corriendo. **Ese es el suelo**, no lo causa lo que estés midiendo.
- Quien la tiene agarrada es **el Xorg de SDDM** (pid bajo, padre `/usr/bin/sddm`,
  `-auth /run/sddm/xauth_…`, `vt2`): el servidor X del gestor de login, que sigue vivo tras entrar
  a la sesión Wayland.
- ⚠️ **Steam NO es la causa**, aunque aparezca en la tabla de procesos de `nvidia-smi`
  (`steamwebhelper`). Medido: **3.47 W con Steam abierto y 3.47 W con Steam cerrado**. En una
  sesión anterior se afirmó lo contrario; era incorrecto.
- Consecuencia: al medir si algo usa la dGPU, mirar la **tabla de procesos** de `nvidia-smi` (¿sale
  tu proceso?) y el **delta** de potencia, no el valor absoluto.
- Comprobar el estado: `cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status`.

## Audio y MPRIS (verificado 2026-07)

Contexto para cualquier cosa de música/reproductores. cava lee del **monitor de un sink**, así que
es indiferente al reproductor (visualiza Zen, VLC o un juego por igual) — pero **no** es indiferente
a la *salida*: ver el aviso de `source = auto` justo abajo.

### Fuente de audio (para cava y similares)

- Monitor del sink: `alsa_output.<sink>.monitor` (el nombre exacto cambia por equipo y por perfil;
  sácalo con `pactl list sinks short`).
- El monitor aparece `SUSPENDED` cuando no suena nada y pasa a `RUNNING` con audio. Es normal:
  no confundirlo con un fallo.

### `source = auto` de cava escucha UNA salida, y no cambia nunca ⚠️ (verificado 2026-08-15)

El PoC de 2026-07 dijo que «autodetecta bien» y eso **se malinterpretó**: autodetecta *una vez*.
El backend de pulse de cava resuelve el monitor del sink **predeterminado al arrancar** y se queda
ahí para siempre. Consecuencias, las dos reales:

- si el audio sale por un sink que **no** es el predeterminado → barras planas;
- si cambias de salida con cava **ya abierto** → barras planas.

Caso que lo destapó: predeterminado = auriculares HyperX, pero el audio del fondo de vídeo iba al
HDMI del ASUS. `pactl list source-outputs` mostraba cava clavado en el monitor de los HyperX
(`IDLE`) mientras el del HDMI estaba `RUNNING`. **No es un fallo de la config ni de cava: es su
diseño.** No se arregla poniendo la fuente a mano — eso solo cambia a qué salida única te atas.

La solución del overlay es `overlay/ml4w-juanjo/scripts/cava-enlazar-audio.sh`: PipeWire permite
enlazar **varias** salidas al mismo puerto de entrada y las **suma**, así que el script engancha el
monitor de *todos* los sinks a `cava:input_FL/FR` con `pw-link`. Lo arranca `cava-toggle.sh` en los
dos modos y se muere solo con cava.

Va **en bucle** (2 s), no de una pasada, porque hay tres cosas que rompen los enlaces y las tres
pasan en uso normal: aparece un sink nuevo (bluetooth, cambio de perfil de la tarjeta), cambia el
sink predeterminado —y al **mover** el stream de cava, pulse-server deshace los enlaces existentes,
los nuestros incluidos— o desaparece un sink. `pw-link` sobre un enlace que ya existe falla con
«File exists» sin duplicar, así que repetir es idempotente y no hay que comparar nada.

Dos trampas al tocar esto:

- **Filtrar los sinks con `pactl`, no con `pw-link -o | grep monitor`.** En esa lista también salen
  `cava:monitor_*` (cava es un stream de captura y expone monitor: enlazarlo a su propia entrada
  es un **bucle de realimentación**) y los medidores de picos de pavucontrol.
- **Nada de `pkill -f cava-enlazar-audio.sh`** para evitar duplicados: ese patrón casa también con
  la shell que ejecuta el script, y se suicida. La instancia única va con `flock`.

Efectos secundarios asumidos: las barras muestran la **suma** de todas las salidas, y mientras cava
está visible **todos los sinks se quedan despiertos** (pasan a tener un consumidor activo) — en el
portátil es consumo extra, acotado porque el toggle mata cava al ocultarlo.

### El navegador se llama `firefox` en el bus MPRIS ⚠️

- Navegador en uso: **Zen, instalado como Flatpak** (`app.zen_browser.zen`). Los procesos son
  `/app/zen/zen`. Firefox nativo (paquete pacman) está instalado pero **no se usa**; **no se
  desinstala de momento** (decisión del usuario, 2026-07).
- **Zen se identifica en el bus MPRIS como `firefox.instance_<n>`**, NO como `zen`: es un fork de
  Gecko y no rebrandeó el nombre del bus. Verificado con `playerctl -l`.
  → **Cualquier config futura de waybar/Quickshell debe filtrar por `firefox`, no por `zen`.**
- **Riesgo latente**: si algún día se arranca Firefox nativo a la vez que Zen, **colisionan en el
  nombre del bus** y no habrá forma de distinguirlos desde una keybind de playerctl. `playerctld`
  está disponible en el bus y mitiga (sigue "el último player activo"). Desinstalar Firefox
  eliminaría el riesgo de raíz — pendiente, no ahora.
- La **carátula sí funciona** pese al sandbox de Flatpak: el `mpris:artUrl` de Zen apunta a un
  fichero real y legible desde el host
  (`~/.var/app/app.zen_browser.zen/data/firefox-mpris/*.png`). El bug conocido de artUrl
  incompleto en Flatpak no aplica aquí.
- ML4W **ya trae un widget MPRIS** en la sidebar de Quickshell
  (`.config/quickshell/SidebarApp/SidebarWindow.qml:508`, `import Quickshell.Services.Mpris`)
  → lo que suene en Zen/VLC ya sale ahí con controles, sin configurar nada.

## Hyprland 0.55 / 0.56: la config es Lua nativa (verificado 2026-07)

Cosas que rompen la intuición heredada de la config clásica de Hyprland. **No redescubrirlas.**

- **No hay `hyprland.conf`.** El entrypoint es `~/.config/hypr/hyprland.lua`, Lua puro con
  `require()`. Verificado en **0.55.4** (portátil) y **0.56.0** (sobremesa): misma API, y ML4W
  sigue usando `hl.window_rule` / `hl.bind` / `hl.dsp.exec_cmd` en `conf/ml4w.lua`.
- El hook `custom.lua` sigue en pie en 0.56: `hyprland.lua:40-43` comprueba que el fichero
  exista y hace `require("custom")` **después** de todos los `conf.*`.
- **`hyprctl dispatch` evalúa su argumento como Lua**, envolviéndolo en `hl.dispatch(...)`. La
  sintaxis de string clásica **ya NO funciona**:
  ```bash
  hyprctl dispatch closewindow class:foo          # ✘ error: ')' expected near 'class'
  hyprctl dispatch 'hl.dsp.workspace.toggle_special("cava")'   # ✔
  ```
- **`hl.dsp.*` solo CONSTRUYE un descriptor, no ejecuta.** Por eso `hyprctl eval 'hl.dsp.window.close(…)'`
  devuelve `ok` con cualquier argumento, incluso inventado: no valida ni dispara nada. **No sirve
  para probar dispatchers.** Quien ejecuta es `hl.dispatch(descriptor)`.
- **`hl.window_rule` SÍ valida los campos**, y ahí `hyprctl eval` es un banco de pruebas fiable:
  ```bash
  hyprctl eval 'hl.window_rule({ name="x", match={class="___fake___"}, workspace="special:cava" })'
  # → ok            (workspace es campo válido)
  hyprctl eval 'hl.window_rule({ name="x", match={class="___fake___"}, inventada=1 })'
  # → error: hl.window_rule: unknown field 'inventada'
  ```
  Usar siempre una clase falsa que no case con nada al probar.
- API real (introspección con `for k,v in pairs(hl.dsp.window)`, volcada a fichero desde Lua
  porque `hyprctl eval` no imprime valores de retorno):
  - `hl.dsp`: `cursor, dpms, event, exec_cmd, exec_raw, exit, focus, force_idle,
    force_renderer_reload, global, group, layout, no_op, pass, send_key_state, send_shortcut,
    submap, window, workspace`
  - `hl.dsp.window`: `alter_zorder, bring_to_top, center, clear_tags, close, cycle_next,
    deny_from_group, drag, float, fullscreen, fullscreen_state, kill, move, pin, pseudo, resize,
    set_prop, signal, swap, tag, toggle_swallow`
  - `hl.dsp.workspace`: `move, rename, swap_monitors, toggle_special`
- **Hook oficial de personalización**: `~/.config/hypr/custom.lua`. `hyprland.lua:39-44` lo carga
  con `require("custom")` **el último**, después de todos los `conf.*` → gana sobre cualquier bind
  anterior. ML4W **no lo trae de serie**. ⚠️ Pero `~/.config/hypr` **sí** es symlink al árbol de
  ML4W, así que el fichero cae DENTRO del árbol gestionado → lo vigila `check.sh`.
- Sintaxis de bind (`conf/keybindings/default.lua:5`):
  ```lua
  hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("~/ruta/script.sh"), { description = "..." })
  ```
- `modmask` en `hyprctl binds`: SUPER=64, SHIFT=1 → **SUPER+SHIFT = 65**.
- Workspace especial que ya trae ML4W: **`magic`** (SUPER+S), sin ninguna app asignada.
  Conviene dejarlo libre y crear los nuestros aparte.

### Binds SUPER+SHIFT ocupadas por ML4W (para no pisar)

`A B G H M Q R S T W` — la `H` es el toggle de hyprsunset. Libres a 2026-07: `C D E F I J K L N O
P U V X Y Z` (usamos la **C** para cava).

## Rutas de ML4W (dónde vive todo)

- Árbol real: `~/.mydotfiles/com.ml4w.dotfiles.stable/.config/...`
- Symlinkeado a: `~/.config/...` (editar `~/.config/waybar/...` edita el árbol de ML4W).
- `~/.mydotfiles` **NO es repo git**. Contiene: `backups/`, la carpeta de dotfiles y
  `ml4w-autostart.log`.
- ⚠️ **El instalador/updater de ML4W sobrescribe este árbol en cada actualización.** Por eso
  usamos overlay (ver `01-estrategia-overlay.md`).

## Waybar — estado actual

- **Tema activo**: `ml4w-glass-center`.
- Config del tema: `~/.config/waybar/themes/ml4w-glass-center/config`
  - `include`:
    ```
    ~/.config/ml4w/settings/waybar-quicklinks.json
    ~/.config/waybar/modules.json
    ```
  - `modules-right` actual:
    ```
    custom/updates, pulseaudio, //backlight, bluetooth, network, battery,
    group/hardware, group/tools, tray, custom/notification, custom/exit,
    custom/ml4w-welcome
    ```
- `~/.config/waybar/modules.json`:
  - YA define `cpu`, `memory`, `disk`, etc. **NO** define `temperature` ni módulo GPU.
  - Define un **drawer** `group/hardware` (línea ~266) que agrupa:
    ```
    custom/system, disk, cpu, memory, hyprland/language
    ```
    → **Este grupo es el sitio natural para meter la temp de CPU y GPU.**
- Estilo de los módulos existentes (referencia para imitar formato/`on-click`):
  ```jsonc
  "cpu": {
    "format": "/ C {usage}% ",
    "on-click": "~/.config/ml4w/settings/system-monitor.sh",
    "on-scroll-up": "true",
    "on-scroll-down": "true"
  }
  ```
