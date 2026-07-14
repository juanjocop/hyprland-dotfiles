# 02 — Tarea: temperaturas de CPU y GPU en la waybar

Primera tarea funcional: recuperar lo que traía el config por defecto de CachyOS y ML4W no
incluye. **Todos los cambios se hacen en `overlay/` y se despliegan con `aplicar.sh`.**

## Enfoque: theme propio de waybar (NO parchear el theme de ML4W)

> Decisión tomada (2026-07) tras investigar cómo funcionan los themes de ML4W. Sustituye al
> plan anterior de parchear `modules.json` + el `config` del theme de ML4W.

Un theme de waybar en ML4W es una **carpeta autocontenida** en `~/.config/waybar/themes/<n>/`.
El selector (`themeswitcher.sh`) **descubre los themes escaneando esa carpeta**, así que un
theme propio aparece solo en el menú sin registrar nada. Por eso, en vez de tocar archivos de
ML4W (que el updater sobrescribe), creamos **nuestro propio theme basado en `ml4w-glass`**:

- No tocamos ningún archivo propiedad de ML4W → **cero deriva upstream** en lo nuestro.
- Controlamos el **layout** de la barra (el `config` del theme es lo que decide qué módulos
  se muestran y dónde; por eso al cambiar de theme se movía todo).
- Queda **100% autocontenido**: una sola carpeta con layout + estilo + módulos custom.

### Cómo funciona un theme (verificado)

- `themes/<n>/config` → layout: márgenes y `modules-left/center/right`. Hace `include` de
  `~/.config/waybar/modules.json` (compartido) y de lo que añadamos.
- `themes/<n>/<variación>/style.css` → aspecto visual (colores, blur, formas).
- `themes/<n>/<variación>/config.sh` → solo `theme_name="..."` (nombre en el selector).
- Theme activo guardado en `~/.config/ml4w/settings/waybar-theme.sh` con formato
  `/CARPETA;/CARPETA/VARIACIÓN` (ej. `/ml4w-glass-juanjo;/ml4w-glass-juanjo/default`).

## Estructura a crear en el overlay

```
overlay/waybar/themes/ml4w-glass-juanjo/
  config                 # copia del config de ml4w-glass + nuestro layout + include del custom
  modules-custom.json    # NUESTROS módulos: temperature (CPU) y custom/gputemp
  default/
    style.css            # copia del style.css de ml4w-glass (retocable después)
    config.sh            # theme_name="Glass Juanjo"
```

> Base = `~/.config/waybar/themes/ml4w-glass/` (copiar su `config` y `default/style.css` como
> punto de partida). El módulo `temperature` es nativo de waybar; `modules.json` de ML4W NO lo
> define, así que lo definimos nosotros en `modules-custom.json` (junto al de GPU) y lo
> incluimos desde nuestro `config` — sin depender de tocar el `modules.json` compartido.

## 1) `config` de nuestro theme

Partir del `config` de `ml4w-glass` y:

- Añadir el include de nuestros módulos:
  ```jsonc
  "include": [
    "~/.config/ml4w/settings/waybar-quicklinks.json",
    "~/.config/waybar/modules.json",
    "~/.config/waybar/themes/ml4w-glass-juanjo/modules-custom.json"
  ],
  ```
- Meter las temperaturas en el drawer de hardware. El `group/hardware` se define en el
  `modules.json` compartido agrupando `custom/system, disk, cpu, memory, hyprland/language`.
  Como no queremos tocar ese archivo, hay dos opciones (decidir al implementar):
  - **A**: colocar `"temperature"` y `"custom/gputemp"` sueltos en `modules-right` de nuestro
    `config` (junto a `battery`, p.ej.). Simple, no depende del grupo compartido.
  - **B**: redefinir un `group/hardware` propio en `modules-custom.json` que incluya las temps,
    y usarlo en `modules-right`. Más "ordenado" pero duplica el grupo.
  → Recomendado empezar por **A**.

## 2) Temp CPU — módulo nativo `temperature`

En `overlay/waybar/themes/ml4w-glass-juanjo/modules-custom.json`:

```jsonc
"temperature": {
  "hwmon-path-abs": "/sys/devices/platform/coretemp.0/hwmon",
  "input-filename": "temp1_input",
  "critical-threshold": 85,
  "interval": 5,
  "format": "󰔏 {temperatureC}°C",
  "format-critical": "󰸁 {temperatureC}°C",
  "tooltip": true
}
```

> `hwmon-path-abs` + `input-filename` es la forma **estable** (evita el `hwmonN` variable).
> Verificado: `/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp1_input`.

## 3) Temp GPU NVIDIA — módulo `custom/gputemp`

En el mismo `modules-custom.json`:

```jsonc
"custom/gputemp": {
  "exec": "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | awk '{print \"󰢮 \"$1\"°C\"}'",
  "interval": 5,
  "tooltip": true,
  "tooltip-format": "GPU NVIDIA GTX 1060",
  "on-click": "~/.config/ml4w/settings/system-monitor.sh"
}
```

### ⚠️ Aviso batería (Optimus)

Sondear `nvidia-smi` cada 5 s **puede mantener despierta la dGPU** y penalizar batería/calor.
Opciones (decidir con el usuario en la próxima sesión):

- **A (simple)**: dejarlo así; en portátil enchufado no importa.
- **B (ahorro)**: `interval` mayor (15–30 s).
- **C (condicional)**: script que muestre la temp solo si la dGPU ya está activa
  (p.ej. comprobando procesos en `nvidia-smi` o el estado de
  `/sys/bus/pci/devices/0000:01:00.0/power/runtime_status`), y que no la despierte si duerme.

## 4) Activar nuestro theme

`aplicar.sh` debe, además de copiar la carpeta, **fijar el theme activo**:

```bash
echo "/ml4w-glass-juanjo;/ml4w-glass-juanjo/default" > ~/.config/ml4w/settings/waybar-theme.sh
~/.config/waybar/launch.sh    # relee el theme activo y relanza waybar
```

(Alternativa manual la primera vez: seleccionarlo desde el themeswitcher de ML4W, que ya lo
lista solo.)

## Validación (tras `./aplicar.sh`)

```bash
cat ~/.config/ml4w/settings/waybar-theme.sh   # debe apuntar a ml4w-glass-juanjo
sensors | grep 'Package id 0'                 # comparar con la barra (CPU)
nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits   # comparar (GPU)
```

Debe verse 󰔏 temp CPU y 󰢮 temp GPU, coincidiendo con los comandos. Si un glyph no se ve, es
tema de fuente Nerd Font → usar emoji (🌡️ / 🎮) como fallback.

> **Nota sobre `launch.sh`**: contiene una sección "Remove incompatible themes" que hace
> `rm -rf` de carpetas conocidas de ML4W. Nuestro nombre propio (`ml4w-glass-juanjo`) no
> colisiona, pero por eso `aplicar.sh` sigue siendo necesario tras cada update de ML4W (por si
> el updater poda carpetas desconocidas).