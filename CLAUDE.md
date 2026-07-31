# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

The **overlay repository** customizing the **ML4W** Hyprland dotfiles on the user's CachyOS
laptop. It is a git repo, and the overlay is **built and in production**: `overlay/`,
`baseline/`, `aplicar.sh`, `check.sh` and `capturar-baseline.sh` all exist and work. The
numbered Markdown docs are now design history and verified reference, not a to-do.

**`README.md` is the source of truth for current state** — read it first. It lists what is
deployed and the three-command workflow (`check.sh` → `aplicar.sh` → `check.sh`).

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

Layout (exists — see `01-estrategia-overlay.md` for the design rationale):

- `overlay/` — our version of each customized file (source of truth).
- `baseline/` — a pristine copy of those same files as ML4W ships them (for 3-way diffing
  after upstream updates).
- `aplicar.sh` — deploys everything in `overlay/` onto the live tree and restarts what needs it.
- `capturar-baseline.sh` — snapshots the ML4W base files into `baseline/`.
- `check.sh` — **core tooling, not optional.** Two checks: (1) our files deployed (overlay ≠
  live → run `aplicar.sh`) and (2) base drift (baseline ≠ live → ML4W updated a base we copied
  from). Run before `aplicar.sh` after each ML4W update.

Prefer deploying into **namespaces ML4W doesn't own** (`~/.config/cava/`,
`~/.config/ml4w-juanjo/`) — the updater never prunes them, so there's zero drift. Files that
must land inside the ML4W tree (anything under `~/.config/hypr`, which is a symlink into it)
have to be listed in `check.sh`.

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

**This overlay runs on two machines** (the same overlay is applied on both — see the
`multi-equipo` commit). Hardware differs, so any hardware-specific detail below is tagged:

- **Portátil (laptop)** — **Optimus**: Intel UHD 630 iGPU + NVIDIA GTX 1060 Mobile dGPU
  (proprietary drivers). This is the machine most of the numbered docs were originally
  written against.
- **Sobremesa (desktop)**, hostname `cachyos-equipaso` — **AMD Ryzen 7 9800X3D** (has an
  integrated Radeon iGPU, `amdgpu`) + **NVIDIA RTX 5070 Ti** (Blackwell, open kernel module
  driver `610.x`). The **monitors hang off the NVIDIA** (card1: DP-1 240Hz + DP-2); the AMD
  iGPU has nothing plugged in, so `amdgpu ... Cannot find any crtc or sizes` in the journal
  is **benign noise**. The **black screen after the monitors slept was not** an NVIDIA modeset
  quirk, as first assumed: Hyprland *died* with SIGSEGV inside aquamarine 0.13.0
  (`SDRMConnector::releaseCommitBuffers`, expired weak pointer) when the DP link dropped and
  NVIDIA reported it as a hotplug. Fixed upstream by `c0bd9ed`, shipped in **aquamarine 0.14.0**
  (installed 2026-07-29); the temporary `hypridle.conf` mitigation was reverted 2026-07-31 —
  full diagnosis in issue #1. Moral: if a black screen returns, check `coredumpctl` for a
  Hyprland crash **before** blaming the driver.

Common to both:

- CachyOS (Arch-based), Hyprland WM, **fish** shell. ML4W with the newer **Lua-based**
  Hyprland config.
- **Hyprland 0.56 config is native Lua, and it breaks inherited intuition** — there is no
  `hyprland.conf`, and `hyprctl dispatch` evaluates its argument as Lua
  (`hyprctl dispatch closewindow class:foo` errors; use
  `hyprctl dispatch 'hl.dsp.workspace.toggle_special("cava")'`). Also: `hl.dsp.*` only *builds*
  a descriptor, so `hyprctl eval 'hl.dsp.window.close(anything)'` returns `ok` without
  validating or executing — **it is not a way to test dispatchers**. `hl.window_rule` *does*
  validate fields, so `hyprctl eval` is a reliable bench for those (use a fake class).
  `~/.config/hypr/custom.lua` is ML4W's official hook, loaded last.
  **Full verified details in `00-contexto-y-hardware.md` — don't re-derive them.**
- ML4W tree lives at `~/.mydotfiles/com.ml4w.dotfiles.stable/.config/...`, symlinked into
  `~/.config/...`. Editing `~/.config/waybar/...` edits the ML4W tree. `~/.mydotfiles` is
  **not** a git repo.
- Active waybar theme (as shipped): `ml4w-glass-center`. We replace it with our own
  `ml4w-glass-juanjo` (see the customization decision above). `modules.json` at the waybar
  root is **shared** by all themes via `include`; each theme's `config` decides which modules
  show and where.

### Verified sensor commands (don't re-derive)

`hwmonN` is **not** stable across boots, so use the stable device path. **The CPU sensor
differs per machine** (Intel `coretemp` vs AMD `k10temp`):

- CPU temp — **laptop (Intel)**: `hwmon-path-abs = /sys/devices/platform/coretemp.0/hwmon`,
  `input-filename = temp1_input`.
- CPU temp — **sobremesa (AMD Ryzen 9800X3D, `k10temp`)**: stable device path
  `/sys/devices/pci0000:00/0000:00:18.3/hwmon`, sensor label **Tctl** (`temp1_input`). There
  is no `coretemp.0` on this machine — a config hardcoding the Intel path shows nothing here.
- GPU temp (both): `nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits`.

### kde-gtk-config rewrites GTK settings behind your back (don't re-derive)

`kde-gtk-config` ships with CachyOS and fires whenever a KDE app starts — even though Plasma
isn't the session. It rewrites `~/.config/gtk-{3.0,4.0}/settings.ini` (and
`~/.config/xsettingsd/xsettingsd.conf`, same mtime to the second — that's how you fingerprint
it) into **KDE's own format**. Verified 2026-07-31; it caused two separate appearance bugs:

- `gtk-application-prefer-dark-theme`: `1` → `true`. ML4W's `run_matugen` compared it
  **numerically**, so the test aborted and matugen regenerated the whole palette in **light**.
  Fixed in `overlay/ml4w/scripts/ml4w-wallpaper` (accepts `1` and `true`, like ML4W's own
  `gtk-theme-switcher.sh` already did).
- `gtk-icon-theme-name`: `breeze-dark` → `breeze`. Tray icons (`nm-applet`) went near-black
  (`#232629` vs `#fcfcfc`) on the dark bar. Fixed in `aplicar.sh` §5d + `check.sh` §6d.

Two things worth knowing when debugging this class of bug:

- **Tray icons are NOT styled by waybar CSS** — they come from the GTK icon theme. Waybar 0.15
  has no `icon-theme` option on `tray` (only `hyprland-workspaces` and `wlr-taskbar` do), so
  the fix is necessarily global. Don't chase `#network { color: … }`.
- **Never overlay `settings.ini` whole**: it holds per-machine values (`gtk-xft-dpi`, cursor),
  so a byte-for-byte overlay breaks the multi-machine invariant. Set only the key you own.

`check.sh` §6c/§6d now detect both regressions, so the workflow catches a recurrence.

## Working rules

- **Never edit the live config by hand.** All customizations go into `overlay/`, then deploy
  with `aplicar.sh`. Live (`~/.config`) is a re-applyable destination, never the source.
- After deploying, relaunch waybar via `~/.config/waybar/launch.sh` (not `SIGUSR2 waybar` —
  we're switching theme, not just reloading content) and validate the bar against the raw
  `sensors` / `nvidia-smi` output (see `02-tarea-temperaturas.md`).
- **Optimus battery caveat (laptop only)**: polling `nvidia-smi` on an interval can keep the
  dGPU awake. The GPU-in-battery behavior is an open decision — confirm with the user before
  committing to a polling interval. Moot on the desktop (no battery, NVIDIA always driving
  the displays).

## Open decisions (ask the user)

- GPU module behavior on battery (see the caveat above).

*(Resolved: the repo is public at `github.com/juanjocop/hyprland-dotfiles`, default branch
`main`.)*
