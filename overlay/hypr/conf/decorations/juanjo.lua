-- -----------------------------------------------------
-- General window decoration
-- name: "Juanjo"
-- gamemode (sin blur, wallpaper nítido detrás) + bordes redondeados + sombra sutil
-- -----------------------------------------------------

hl.config({
    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 0.9,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled = true,
            range = 20,
            render_power = 2,
            color = "rgba(00000040)",
        },

        blur = {
            enabled = false,
        },
    },
})
