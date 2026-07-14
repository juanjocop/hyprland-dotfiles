# 00 — Contexto y hardware (datos verificados)

> Todo lo de aquí está comprobado en el equipo real (2026-07). No hace falta redescubrirlo.

## Entorno

- SO: **CachyOS** (Arch-based). WM: **Hyprland**. Shell del usuario: **fish**.
- Dotfiles: **ML4W** (`com.ml4w.dotfiles.stable`), versión nueva con **config de Hyprland
  basada en Lua**.

## Hardware relevante

- Portátil **Optimus** (gráfica híbrida):
  - iGPU: **Intel UHD 630** (CoffeeLake-H GT2).
  - dGPU: **NVIDIA GeForce GTX 1060 Mobile** (GP106M).
- CPU: 6 núcleos (aparecen Core 0–5 en `sensors`).

## Sensores (comandos verificados)

### CPU — sensor `coretemp`
- `sensors` muestra `coretemp-isa-0000` con `Package id 0` y `Core 0..5`.
- Ruta **estable** (recomendada para waybar; `hwmonN` NO es estable entre arranques):
  ```
  hwmon-path-abs = /sys/devices/platform/coretemp.0/hwmon
  input-filename = temp1_input      # = "Package id 0"
  ```
  Verificado: `/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp1_input` existe.

### GPU — NVIDIA
- `nvidia-smi` disponible y la dGPU responde (drivers propietarios activos).
- Comando para temperatura:
  ```
  nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits
  ```
  Devuelve un entero (ej. `53`).
- Uso/VRAM (para el roadmap): `--query-gpu=utilization.gpu,memory.used,memory.total`.

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
