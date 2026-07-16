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

ShellRoot {
    id: root

    // ── Ajustes visuales ──
    readonly property int stripHeight: 250
    readonly property int barCount: 64      // DEBE coincidir con `bars` en cava-bg/cava-raw.conf
    readonly property int gap: 6
    readonly property int smoothMs: 90      // suavizado entre frames de cava
    readonly property real peakFall: 1.2    // a cuánto cae el pico por frame

    // ── Paleta (matugen). Los valores por defecto son solo el arranque, hasta que carga el JSON ──
    property color colLow: "#b1c5ff"        // primary   → base de la barra
    property color colHigh: "#e1bbdd"       // tertiary  → punta

    FileView {
        id: paletteFile
        path: Quickshell.env("HOME") + "/.config/ml4w/colors/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const p = JSON.parse(paletteFile.text());
                if (p.primary) root.colLow = p.primary;
                if (p.tertiary) root.colHigh = p.tertiary;
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
            implicitHeight: root.stripHeight

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

                        // La barra
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: slot.width
                            height: Math.max(2, slot.height * (slot.level / 100))
                            radius: width / 2
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: Qt.rgba(root.colHigh.r, root.colHigh.g, root.colHigh.b, 0.85)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: root.colLow
                                }
                            }
                            Behavior on height {
                                NumberAnimation {
                                    duration: root.smoothMs
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        // El pico, que cae despacio desde el máximo
                        Rectangle {
                            width: slot.width
                            height: 2
                            radius: 1
                            color: root.colHigh
                            opacity: 0.7
                            visible: slot.peak > 2
                            y: slot.height - Math.max(2, slot.height * (slot.peak / 100)) - height
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
