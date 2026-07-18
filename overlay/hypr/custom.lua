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
