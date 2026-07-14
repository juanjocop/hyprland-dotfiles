# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A **planning/spec repository** for customizing the **ML4W** Hyprland dotfiles on the user's
CachyOS laptop. As of the current state it contains **only Markdown planning documents** —
no git repo, no scripts, no `overlay/`/`baseline/` directories yet. The docs describe work
to be executed in a later session, directly over this folder (`~/Proyectos/hyprland-dotfiles`).

Documentation is written in **Spanish**; match that language when editing these docs or
writing commit messages, unless the user asks otherwise.

## Read order

The numbered docs are meant to be read in sequence, and the data in them is already verified
against the real machine — do not re-discover it:

1. `README.md` — project state and decisions already made.
2. `00-contexto-y-hardware.md` — machine, ML4W paths, verified sensor commands/paths.
3. `01-estrategia-overlay.md` — the overlay repo structure + `aplicar.sh` design.
4. `02-tarea-temperaturas.md` — first concrete task: CPU + GPU temps in waybar.
5. `03-roadmap.md` — subsequent customization steps.

Execution order once building: **overlay strategy → temperatures → validate → roadmap**.

## Core architectural decision: the "overlay" strategy

ML4W's installer **overwrites its tree (`~/.mydotfiles/com.ml4w.dotfiles.stable`) on every
update, ignoring git.** Therefore:

- Do **not** fork ML4W upstream and do **not** `git init` over all of `~/.mydotfiles`.
- Instead this repo is a small **overlay**: it versions only the files we customize, plus a
  script that re-applies them onto the ML4W tree after each update.

Planned layout (to be created — see `01-estrategia-overlay.md` for the full spec):

- `overlay/` — our version of each customized file (source of truth).
- `baseline/` — a pristine copy of those same files as ML4W ships them (for 3-way diffing
  after upstream updates).
- `aplicar.sh` — copies our theme folder → `~/.config/...`, sets it as the active waybar theme
  (writes `~/.config/ml4w/settings/waybar-theme.sh`), and relaunches waybar via `launch.sh`.
- `capturar-baseline.sh` — snapshots the `ml4w-glass` base files into `baseline/`.
- `check.sh` — **core tooling, not optional.** Two checks: (1) our theme deployed (overlay ≠
  live → run `aplicar.sh`) and (2) base drift (baseline ≠ live `ml4w-glass` → ML4W updated the
  base we copied from). Build it with the other two scripts; run before `aplicar.sh` after
  each ML4W update.

### Waybar customization = our own theme (key decision)

Do **not** patch ML4W's shared `modules.json` or an ML4W theme's `config`. Instead we ship a
self-contained custom theme **`ml4w-glass-juanjo`** (based on `ml4w-glass`) under
`overlay/waybar/themes/`. ML4W's theme switcher discovers themes by scanning the folder, so a
new theme folder auto-appears in the picker and — crucially — ML4W's updater never edits it,
so there's essentially no upstream drift on our work. A waybar theme is a self-contained
folder: `config` (bar layout: margins + `modules-left/center/right`, the reason switching
themes moves everything), `<variation>/style.css` (look), `<variation>/config.sh`
(`theme_name`). Our custom modules (`temperature`, `custom/gputemp`) live in the theme's own
`modules-custom.json`, included from its `config`. Full spec in `02-tarea-temperaturas.md`.

## Key facts about the target system

- CachyOS (Arch-based), Hyprland WM, **fish** shell. ML4W with the newer **Lua-based**
  Hyprland config.
- **Optimus** laptop: Intel UHD 630 iGPU + NVIDIA GTX 1060 Mobile dGPU (proprietary drivers).
- ML4W tree lives at `~/.mydotfiles/com.ml4w.dotfiles.stable/.config/...`, symlinked into
  `~/.config/...`. Editing `~/.config/waybar/...` edits the ML4W tree. `~/.mydotfiles` is
  **not** a git repo.
- Active waybar theme (as shipped): `ml4w-glass-center`. We replace it with our own
  `ml4w-glass-juanjo` (see the customization decision above). `modules.json` at the waybar
  root is **shared** by all themes via `include`; each theme's `config` decides which modules
  show and where.

### Verified sensor commands (don't re-derive)

- CPU temp (stable path — `hwmonN` is **not** stable across boots):
  `hwmon-path-abs = /sys/devices/platform/coretemp.0/hwmon`, `input-filename = temp1_input`.
- GPU temp: `nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits`.

## Working rules

- **Never edit the live config by hand.** All customizations go into `overlay/`, then deploy
  with `aplicar.sh`. Live (`~/.config`) is a re-applyable destination, never the source.
- After deploying, relaunch waybar via `~/.config/waybar/launch.sh` (not `SIGUSR2 waybar` —
  we're switching theme, not just reloading content) and validate the bar against the raw
  `sensors` / `nvidia-smi` output (see `02-tarea-temperaturas.md`).
- **Optimus battery caveat**: polling `nvidia-smi` on an interval can keep the dGPU awake.
  The GPU-in-battery behavior is an open decision — confirm with the user before committing
  to a polling interval.

## Open decisions (ask the user)

- GitHub repo visibility (public/private) and final name.
- GPU module behavior on battery (see the caveat above).
