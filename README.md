# Omarchy Autohide

An event-driven auto-hide service plugin for the Omarchy bar.

> [!IMPORTANT]
> This plugin is for **Omarchy 4 (Quattro)**, where the desktop shell and bar
> use [Quickshell](https://quickshell.org/). It is not intended for older
> Omarchy releases that use Waybar.

## Behavior

- Supports bars anchored to the top, bottom, left, or right screen edge.
- Reveals the bar only when the pointer reaches its anchored screen edge.
- Keeps the bar open while the pointer remains over it.
- Hides the bar 1000ms after the pointer leaves that area.
- Leaves the bar visible when the user opens it with the bar hotkey.
- Keeps the bar visible while a bar popout is open.
- Supports multiple monitors, scaling, rotation, and monitor offsets.

A transparent one-pixel Quickshell surface listens for pointer entry at the bar
edge. Omarchy's existing whole-bar hover state handles pointer exit. There is no
cursor polling and no persistent helper process, so the plugin causes no idle
timer wakeups.

## Requirements

- Omarchy with the Quickshell bar
- Hyprland
- Python 3 during installation only

## Install

```bash
git clone https://github.com/ericvrp/omarchy-autohide.git
cd omarchy-autohide
./install.sh
```

The installer:

- Copies the plugin to `~/.config/omarchy/plugins/autohide`.
- Adds `{ "id": "autohide" }` to the existing `plugins` array in
  `~/.config/omarchy/shell.json` without replacing other settings.
- Creates a timestamped backup before changing an existing shell config.
- Restarts the Omarchy shell.

Running `./install.sh` again updates the installed plugin without adding a
duplicate config entry.

## Update

```bash
cd omarchy-autohide
git pull
./install.sh
```

## Uninstall

```bash
cd omarchy-autohide
./uninstall.sh
```

## Configuration

Defaults are near the top of `Service.qml`:

```qml
readonly property int revealThickness: 1
readonly property int hideDelayMs: 1000
```

The active edge is detected from `shell.bar.position`. Increasing
`revealThickness` makes the invisible edge trigger easier to reach, but also
makes that many pixels intercept pointer input while the bar is hidden or was
revealed by the edge trigger.

Re-run `./install.sh` after editing a clone outside the installed plugin
directory.

## License And Warranty

Licensed under the [MIT License](LICENSE).

The software is provided **as is, without warranty of any kind**, express or
implied. See the license for the complete warranty and liability disclaimer.
