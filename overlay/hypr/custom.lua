-- custom.lua — hook oficial de personalización de ML4W. Se despliega a ~/.config/hypr/custom.lua.
--
-- ML4W lo carga EL ÚLTIMO (hyprland.lua:39-44: require("custom"), después de todos los conf.*)
-- y NO lo trae de serie → es el sitio designado para nuestras cosas, y lo que pongamos aquí
-- gana sobre cualquier bind anterior.
--
-- OJO: ~/.config/hypr SÍ es symlink al árbol de ML4W, así que este fichero aterriza DENTRO del
-- árbol gestionado. Un update podría podarlo → check.sh lo vigila.

-- Visualizador de audio, en dos modos excluyentes (encender uno apaga el otro):
--
--   SUPER+SHIFT+C → tile: cava en una ventana kitty, tilada en el workspace actual. Es una
--                   ventana normal, por eso no hay window_rule: sin regla Hyprland ya la coloca.
--   SUPER+ALT+C   → fondo: franja de barras (widget Quickshell) sobre el vídeo de mpvpaper y
--                   debajo de las ventanas, con los colores de matugen.
--
-- Ambas teclas verificadas libres: de las SUPER+SHIFT, ML4W ocupa A B G H M Q R S T W (la H es
-- hyprsunset); de las SUPER+ALT, ocupa A F G S T W y las flechas.
--
-- La ventana del tile se lanza con `--class cava-visualizer`. Esa clase propia no hace falta
-- hoy, pero distingue el visualizador de una kitty cualquiera y deja añadirle reglas aquí sin
-- tocar el script.

hl.bind(
    "SUPER + SHIFT + C",
    hl.dsp.exec_cmd("~/.config/ml4w-juanjo/scripts/cava-toggle.sh tile"),
    { description = "Toggle visualizador cava (ventana)" }
)

hl.bind(
    "SUPER + ALT + C",
    hl.dsp.exec_cmd("~/.config/ml4w-juanjo/scripts/cava-toggle.sh bg"),
    { description = "Toggle visualizador cava (fondo)" }
)

-- SUPER+SHIFT+D → despertar las pantallas a mano. Es la SALIDA DE EMERGENCIA del apagado por
-- inactividad, y existe porque el aviso de vuelta puede perderse: el 2026-08-06 el `on-resume`
-- de hypridle no llegó nunca y la DP-2 se quedó negra 45 min (el porqué, en la cabecera de
-- idle-guard.sh). En ese estado el botón de la barra no sirve de nada — no se ve. A ciegas, esta
-- tecla sí. Tiene que ser un bind de Hyprland precisamente por eso: no depende de ver nada.
--
-- Llama a la MISMA acción que hypridle en su `on-resume`: para al vigilante, borra la marca de
-- apagado y cicla el DPMS con reintentos. Es inofensiva con las pantallas ya encendidas: sin
-- marca no cicla nada, solo lo anota en el log ("reanudación sin apagado previo").
--
-- D verificada libre: de las SUPER+SHIFT, ML4W ocupa A B G H M Q R S T W, los dígitos y las
-- flechas; la C es nuestra (arriba).
hl.bind(
    "SUPER + SHIFT + D",
    hl.dsp.exec_cmd("~/.config/ml4w-juanjo/scripts/idle-guard.sh accion pantallas-on"),
    { description = "Despertar pantallas (rescate del apagado por inactividad)" }
)

-- NOTA sobre el blur de las barras: se hace en Qt (MultiEffect dentro del shell.qml), NO con
-- `hl.layer_rule({ match = { namespace = "cava-bg-juanjo" }, blur = true })`.
--
-- Ese layer_rule es el idiom de ML4W para la waybar (conf/decorations/blur.lua:32) y funciona,
-- pero difumina lo que hay DETRÁS de la capa y depende del blur GLOBAL de Hyprland — que en la
-- variante de decoración activa (`conf/decorations/juanjo.lua`) está **desactivado a propósito**
-- ("gamemode, wallpaper nítido detrás"). Activarlo afectaría a todo el escritorio, no solo a las
-- barras. Por eso el blur va por Qt: difumina las barras en sí y no toca esa decisión.

-- Transparencia de VS Code (code-oss), SOLO para esa clase — el resto de ventanas siguen con la
-- opacidad global de la variante `juanjo` (activa 1.0 / inactiva 0.9).
--
-- OJO — matiz honesto: la opacidad de Hyprland es de VENTANA ENTERA, no "solo del fondo". A 0.95
-- el texto también está al 95%, pero ese 5% es imperceptible para leer y basta para que el fondo
-- respire un poco. Transparencia real solo-fondo (texto 100% opaco) exigiría inyectar CSS con una
-- extensión, que no es nativo y se rompe en cada update de VS Code — descartado a propósito.
--
-- `opacity = "<activa> override <inactiva> override"`: el `override` evita que se multiplique con
-- el inactive_opacity=0.9 global, así los valores son exactos. Suben/bajan libremente aquí.
hl.window_rule({
    name = "code-oss-opacity",
    match = { class = "code-oss" },
    opacity = "0.95 override 0.88 override",
})

-- Unreal Editor (UE 5.8, binario de Epic, lanzado con ~/.local/bin/ue5). Ver decisión 53 en
-- ~/Proyectos/UmbraSolaris/docs/decisions.md.
--
-- El editor de la 5.8 es SDL 3 con backend Wayland NATIVO (verificado: `Using SDL video driver
-- 'wayland'`, sin XWayland). Todas sus ventanas comparten el app_id `UnrealEditor` (splash,
-- Project Browser, diálogos, pestañas arrancadas, ventana principal). Tilar todo eso es un incordio (el splash y los diálogos se estiran a media
-- pantalla), así que la regla base FLOTA todo `UnrealEditor` y una segunda regla, posterior
-- (gana por orden), vuelve a TILAR únicamente la ventana principal, que se distingue por el
-- título `<Proyecto> - Unreal Editor` (verificado con `hyprctl clients`: class=UnrealEditor,
-- title="SmokeTest - Unreal Editor", xwayland=false, floating=false). Los menús desplegables y
-- tooltips son popups de xdg-shell: Hyprland no los tila y no necesitan regla.
--
-- Los `match` son regex RE2 (Rule.hpp → RegexMatchEngine), NO globs: por eso van anclados.
-- Si tras el primer arranque algún título real no encaja, se ajusta con `hyprctl clients`.
hl.window_rule({
    name = "unreal-editor-secondary-float",
    match = { class = "^UnrealEditor$" },
    float = true,
})
hl.window_rule({
    name = "unreal-editor-main-tile",
    match = { class = "^UnrealEditor$", title = "^.* - Unreal Editor.*$" },
    tile = true,
})
