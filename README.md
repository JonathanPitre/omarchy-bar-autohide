# Omarchy Autohide

An efficient auto-hide service plugin for the Omarchy bar.

> [!IMPORTANT]
> This plugin is for **Omarchy 4 (Quattro)**, where the desktop shell and bar
> use [Quickshell](https://quickshell.org/). It is not intended for older
> Omarchy releases that use Waybar.

## Behavior

- Supports bars anchored to the top, bottom, left, or right screen edge.
- Reveals the bar only when the pointer reaches its anchored screen edge.
- Keeps the bar open while the pointer remains within the bar's current
  thickness.
- Hides the bar 100ms after the pointer leaves that area.
- Keeps the bar visible while a bar popout is open.
- Handles workspace switches that cause the bar to become visible again.
- Supports scaled, rotated, and vertically offset monitors.

Cursor position is read through Hyprland's Unix socket by one persistent Python
process. It does not repeatedly launch `bash` or `hyprctl`.

## Requirements

- Omarchy with the Quickshell bar
- Hyprland
- Python 3

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
readonly property int revealDistance: 0
readonly property int hideDelayMs: 100
```

The closing boundary is detected automatically from Omarchy's live
`shell.bar.barSize` value. The active edge is detected from
`shell.bar.position`.

Polling frequency is controlled by `POLL_INTERVAL_SECONDS` in
`cursor_poll.py`.

Re-run `./install.sh` after editing a clone outside the installed plugin
directory.

## License And Warranty

Licensed under the [MIT License](LICENSE).

The software is provided **as is, without warranty of any kind**, express or
implied. See the license for the complete warranty and liability disclaimer.
