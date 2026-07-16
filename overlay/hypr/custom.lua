-- custom.lua — hook oficial de personalización de ML4W. Se despliega a ~/.config/hypr/custom.lua.
--
-- ML4W lo carga EL ÚLTIMO (hyprland.lua:39-44: require("custom"), después de todos los conf.*)
-- y NO lo trae de serie → es el sitio designado para nuestras cosas, y lo que pongamos aquí
-- gana sobre cualquier bind anterior.
--
-- OJO: ~/.config/hypr SÍ es symlink al árbol de ML4W, así que este fichero aterriza DENTRO del
-- árbol gestionado. Un update podría podarlo → check.sh lo vigila.

-- Visualizador de audio (cava) en un workspace especial propio.
-- Usamos "special:cava" y NO el "special:magic" que ya trae ML4W (SUPER+S, conf/keybindings/
-- default.lua:93-95): magic es el scratchpad genérico y conviene dejarlo libre.
--
-- La clase propia es NECESARIA: el terminal es kitty, y sin --class esta regla cazaría todas
-- las ventanas de kitty.
hl.window_rule({
    name = "cava-visualizer",
    match = { class = "cava-visualizer" },
    workspace = "special:cava",
})

-- SUPER+SHIFT+C — verificado libre (ocupadas con SHIFT: A B G H M Q R S T W; H = hyprsunset).
hl.bind(
    "SUPER + SHIFT + C",
    hl.dsp.exec_cmd("~/.config/ml4w-juanjo/scripts/cava-toggle.sh"),
    { description = "Toggle visualizador cava" }
)
