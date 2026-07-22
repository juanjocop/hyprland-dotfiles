// cava-bg — franja de barras de audio en el fondo del escritorio.
//
// Se lanza con `qs -p ~/.config/ml4w-juanjo/quickshell/cavabg` desde cava-toggle.sh (SUPER+ALT+C).
// Namespace propio fuera del árbol de ML4W → cero deriva; ML4W corre sus propias instancias de
// quickshell aparte y esta no las toca.
//
// Cómo convive con el vídeo: WlrLayer.Bottom cae en el NIVEL 1, o sea encima de mpvpaper
// (nivel 0) y debajo de waybar (nivel 2) y de las ventanas. Verificado en la máquina.
//
// Los colores salen de la paleta de matugen de ML4W, así que pegan con waybar y los bordes.
// Como el FileView vigila el fichero, al cambiar de wallpaper matugen lo regenera y las barras
// se re-colorean solas, sin reiniciar el widget.

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects

ShellRoot {
    id: root

    // ── Ajustes visuales ──
    //
    // Alto de la franja, como FRACCIÓN del alto de la pantalla y no en px fijos: los 250 px se
    // calibraron en 1080p, y en un 1440p esos mismos píxeles ocupan un 25 % menos de pantalla
    // (se veían bajas). Con la proporción, cada monitor recibe el mismo peso visual y el overlay
    // sigue siendo idéntico en las dos máquinas — que es justo lo que se evita con un valor
    // por equipo.
    //
    //   1080p → 250 px (idéntico a antes)   ·   1440p → 333 px
    //
    // Para cambiar el tamaño, toca este ratio, no píxeles.
    readonly property real stripRatio: 250 / 1080   // ≈ 0.231
    readonly property int barCount: 64      // DEBE coincidir con `bars` en cava-bg/cava-raw.conf
    readonly property int gap: 6
    readonly property int smoothMs: 90      // suavizado entre frames de cava
    readonly property real peakFall: 1.2    // a cuánto cae el pico por frame

    // Blur de las barras. Se hace en Qt (MultiEffect) y NO con el layer_rule de Hyprland: aquel
    // difumina lo que hay DETRÁS y depende del blur global, que la variante de decoración activa
    // (conf/decorations/juanjo.lua) tiene apagado a propósito ("gamemode, wallpaper nítido").
    // Ver la nota en overlay/hypr/custom.lua.
    //
    // `barBlur` va de 0 a 1 y es fracción de `blurMaxPx`: 0.4 × 24 ≈ 10px de difuminado.
    // (0.5 ≈ 12px resultó excesivo, 0.3 se quedó corto.)
    readonly property real barBlur: 0.4
    readonly property int blurMaxPx: 24

    // Transparencia del conjunto: deja asomar el vídeo a través de las barras.
    // Va emparejada con `barBlur`: cuanto más blur, menos se nota la transparencia (el desenfoque
    // reparte el color sobre más superficie y se lee como mancha sólida), así que al subir uno hay
    // que bajar la otra. Con blur 0.4, 0.7 es el punto donde el vídeo sigue asomando.
    readonly property real stripOpacity: 0.7

    // ── Glow ──
    //
    // Blur y glow NO son lo mismo, aunque los dos usen desenfoque por debajo:
    //   · blur solo  → la barra ENTERA se emborrona y pierde el filo.
    //   · glow       → la barra sigue NÍTIDA y el desenfoque queda como halo alrededor, tipo neón.
    //
    // Se consigue con dos capas: primero la copia borrosa (el halo) y encima la copia nítida.
    // Por eso el blur de arriba pasa a ser el halo, y `glowCore` es cuánto pesa la copia nítida
    // que va encima.
    //
    // Probado y DESCARTADO (2026-07): no aportaba lo suficiente para lo que cuesta — duplica la
    // composición (las barras se renderizan dos veces por frame, a 60fps). Se deja montado y a un
    // `glowEnabled = true` de distancia por si algún día apetece.
    readonly property bool glowEnabled: false
    readonly property real glowCore: 0.9

    // ── Paleta (matugen) ──
    //
    // OJO con la elección de colores: esta paleta es Material You OSCURA (background #121318), así
    // que `primary` (#b1c5ff) y `tertiary` (#e1bbdd) son colores de PRIMER PLANO — dos pasteles
    // claros con casi la misma luminosidad. Puestos en degradado se leen como un color plano; fue
    // justo lo que pasó en la v1. El contraste está en los `_container`, que son las variantes
    // oscuras: `primary_container` es #304578 (azul marino).
    //
    // De ahí el degradado de 3 paradas: marino oscuro en la base → azul claro → rosa en la punta.
    // Así hay recorrido de luminosidad Y de tono. Los defaults de abajo solo valen hasta que carga
    // el JSON.
    property color colBase: "#304578"       // primary_container → base de la barra
    property color colMid: "#b1c5ff"        // primary
    property color colTip: "#e1bbdd"        // tertiary → punta

    FileView {
        id: paletteFile
        path: Quickshell.env("HOME") + "/.config/ml4w/colors/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const p = JSON.parse(paletteFile.text());
                if (p.primary_container)
                    root.colBase = p.primary_container;
                if (p.primary)
                    root.colMid = p.primary;
                if (p.tertiary)
                    root.colTip = p.tertiary;
            } catch (e) {
                // Paleta ilegible o a medio escribir: nos quedamos con los colores actuales.
            }
        }
    }

    // ── Datos de cava ──
    property var levels: new Array(root.barCount).fill(0)
    property var peaks: new Array(root.barCount).fill(0)

    Process {
        running: true
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/ml4w-juanjo/cava-bg/cava-raw.conf"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                // Formato raw ascii: "12;20;15;…;" — el ; final deja un elemento vacío al split.
                const vals = data.split(";").filter(s => s.length > 0).map(s => parseInt(s, 10));
                if (vals.length === 0)
                    return;
                const pk = root.peaks.slice();
                for (let i = 0; i < vals.length && i < pk.length; i++)
                    pk[i] = Math.max(vals[i], pk[i] - root.peakFall);
                root.levels = vals;
                root.peaks = pk;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "cava-bg-juanjo"
            exclusionMode: ExclusionMode.Ignore   // no reserva espacio: las ventanas la ignoran
            color: "transparent"

            anchors {
                bottom: true
                left: true
                right: true
            }
            // Proporcional a ESTA pantalla: con monitores de distinto alto, cada franja se
            // dimensiona sola en vez de heredar un px fijo pensado para otra resolución.
            implicitHeight: Math.round(win.modelData.height * root.stripRatio)

            // Solo LAS BARRAS van en esta capa oculta; quien las pinta en pantalla es el
            // MultiEffect de abajo, ya difuminadas. Los picos NO van aquí (ver más abajo).
            Item {
                id: barsSource
                anchors.fill: parent
                visible: false
                layer.enabled: true

                Row {
                    id: barRow
                    anchors.fill: parent
                    spacing: root.gap

                    Repeater {
                        model: root.barCount

                        delegate: Item {
                            id: slot
                            required property int index

                            width: (barRow.width - root.gap * (root.barCount - 1)) / root.barCount
                            height: barRow.height

                            readonly property real level: root.levels[index] ?? 0
                            readonly property real peak: root.peaks[index] ?? 0

                            // La barra. En Gradient, position 0.0 es ARRIBA (la punta) y 1.0 es
                            // ABAJO (la base); la barra crece desde abajo → punta clara, base
                            // oscura.
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: slot.width
                                height: Math.max(2, slot.height * (slot.level / 100))
                                radius: width / 2
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0.0
                                        color: root.colTip
                                    }
                                    GradientStop {
                                        position: 0.55
                                        color: root.colMid
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: root.colBase
                                    }
                                }
                                Behavior on height {
                                    NumberAnimation {
                                        duration: root.smoothMs
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }

                        }
                    }
                }
            }

            // 1) El halo: la copia borrosa. Va debajo (en QML, lo declarado después se pinta encima).
            //
            // ⚠️ `autoPaddingEnabled` DEBE quedarse en false. Sirve para que el blur no se recorte
            // en los bordes, pero amplía el área de render del efecto y, con el efecto anclado a la
            // franja, DESPLAZA las barras hacia abajo. Como los picos se dibujan directos (sin
            // pasar por el MultiEffect), quedaban en su sitio y las barras no → se veían
            // descuadrados entre sí. Verificado con capturas: en false alinean.
            MultiEffect {
                anchors.fill: parent
                source: barsSource
                opacity: root.stripOpacity
                blurEnabled: true
                blur: root.barBlur
                blurMax: root.blurMaxPx
                autoPaddingEnabled: false
            }

            // 2) El núcleo nítido encima → glow. Sin efectos activos, MultiEffect solo repinta su
            //    source tal cual; es la forma más simple de dibujar la copia sin blur.
            MultiEffect {
                anchors.fill: parent
                source: barsSource
                visible: root.glowEnabled
                opacity: root.stripOpacity * root.glowCore
                blurEnabled: false
            }

            // 3) Los picos, FUERA del blur y por tanto nítidos.
            //
            // Antes vivían dentro del delegate de cada barra, o sea dentro de `barsSource`, y al
            // añadir el blur desaparecieron: una línea de 2px difuminada con radio ~10px se
            // reparte sobre ~20px y su intensidad cae a ~1/10 → invisible. Dibujarlos aparte los
            // deja crujientes sobre unas barras suaves, que además queda mejor que antes.
            Row {
                id: peakRow
                anchors.fill: parent
                spacing: root.gap
                opacity: root.stripOpacity

                Repeater {
                    model: root.barCount

                    delegate: Item {
                        id: peakSlot
                        required property int index

                        width: (peakRow.width - root.gap * (root.barCount - 1)) / root.barCount
                        height: peakRow.height

                        readonly property real peak: root.peaks[index] ?? 0

                        Rectangle {
                            width: peakSlot.width
                            height: 2
                            radius: 1
                            color: root.colTip
                            opacity: 0.7
                            visible: peakSlot.peak > 2
                            y: peakSlot.height - Math.max(2, peakSlot.height * (peakSlot.peak / 100)) - height
                            Behavior on y {
                                NumberAnimation {
                                    duration: root.smoothMs
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
