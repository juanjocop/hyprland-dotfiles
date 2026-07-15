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

## Estructura del repo

```
overlay/                     ← fuente de verdad: solo lo que personalizamos
  waybar/themes/ml4w-glass-juanjo/   theme propio (temps + botón fondo vídeo)
  hypr/hyprsunset.conf               horario de luz nocturna
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
