# hyprland-dotfiles — personalización de ML4W sobre CachyOS

Base de personalización de los dotfiles **ML4W** (Hyprland) para el equipo de juanjocop.
Este repo/carpeta es el **overlay**: guarda solo lo que personalizamos por encima de ML4W,
para que las actualizaciones de ML4W no se lleven por delante nuestro trabajo.

## Estado actual

- **Fase**: SPEC escrito. Todavía NO se ha creado el repo git real, ni se ha subido a GitHub,
  ni se ha tocado el sistema en vivo (`~/.config`, `~/.mydotfiles`).
- Estos documentos son el plan para ejecutar en una **próxima sesión abierta directamente
  sobre esta carpeta** (`~/Proyectos/hyprland-dotfiles`).

## Cómo retomar en la próxima sesión

1. Abrir Claude Code con working dir = `~/Proyectos/hyprland-dotfiles`.
2. Leer los documentos en orden:
   - `00-contexto-y-hardware.md` — qué equipo es, rutas de ML4W, sensores. **Datos ya
     verificados; no hace falta redescubrirlos.**
   - `01-estrategia-overlay.md` — cómo montar el repo overlay + GitHub + `aplicar.sh`.
   - `02-tarea-temperaturas.md` — primera tarea concreta: temp CPU + GPU en la waybar.
   - `03-roadmap.md` — siguientes pasos de personalización.
3. Ejecutar en este orden: **estrategia overlay → temperaturas → validar → roadmap**.

## Decisiones ya tomadas

- **Estrategia git = repo overlay** (NO fork del upstream de ML4W, NO trackear todo
  `~/.mydotfiles`). Motivo: el instalador de ML4W sobrescribe su árbol en cada update
  ignorando git; un fork pelearía con eso.
- **Primera tarea funcional** = recuperar las temperaturas de CPU y GPU que traía el config
  por defecto de CachyOS y que ML4W no incluye.
- **Personalización de la waybar = theme propio** (`ml4w-glass-juanjo`, basado en
  `ml4w-glass`), NO parchear el theme de ML4W. Motivo: el selector de ML4W descubre los themes
  escaneando la carpeta, y un theme nuestro es una carpeta nueva que el updater no toca → cero
  deriva upstream y layout de la barra bajo nuestro control. Ver `02-tarea-temperaturas.md`.

## Pendiente de decidir (próxima sesión)

- Nombre y visibilidad del repo en GitHub (público/privado).
- Confirmar el comportamiento del módulo GPU en batería (ver `02-tarea-temperaturas.md`).
