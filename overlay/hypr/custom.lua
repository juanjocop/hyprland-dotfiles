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
