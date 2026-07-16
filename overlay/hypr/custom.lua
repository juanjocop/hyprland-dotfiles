-- custom.lua — hook oficial de personalización de ML4W. Se despliega a ~/.config/hypr/custom.lua.
--
-- ML4W lo carga EL ÚLTIMO (hyprland.lua:39-44: require("custom"), después de todos los conf.*)
-- y NO lo trae de serie → es el sitio designado para nuestras cosas, y lo que pongamos aquí
-- gana sobre cualquier bind anterior.
--
-- OJO: ~/.config/hypr SÍ es symlink al árbol de ML4W, así que este fichero aterriza DENTRO del
-- árbol gestionado. Un update podría podarlo → check.sh lo vigila.

-- Visualizador de audio (cava). Es una ventana NORMAL: nace tilada en el workspace en el que
-- estés y se coloca con las demás. Por eso aquí no hay window_rule — sin regla, Hyprland ya
-- hace lo que queremos.
--
-- (Antes vivía en un workspace especial `special:cava`, pero tapaba la pantalla entera: una
-- ventana sola en un workspace propio ocupa todo. Se descartó a favor del tile normal.)
--
-- La ventana se lanza con `--class cava-visualizer` (ver cava-toggle.sh). Esa clase propia no
-- hace falta hoy, pero distingue el visualizador de una kitty cualquiera y deja la puerta
-- abierta a añadirle reglas aquí sin tocar el script.
hl.bind(
    "SUPER + SHIFT + C",
    hl.dsp.exec_cmd("~/.config/ml4w-juanjo/scripts/cava-toggle.sh"),
    { description = "Toggle visualizador cava" }
)
