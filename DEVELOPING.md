# Developing Omarchy Bar Autohide

## Requirements

- Omarchy with the Quickshell bar
- Hyprland
- Python 3 for the local development helpers

## Local Testing

The scripts under `scripts/` are local development helpers. Omarchy does not
run them during normal plugin installation, updates, or removal.

Install the current working tree:

```bash
./scripts/dev-install.sh
```

The development installer:

- Copies the plugin to `~/.config/omarchy/plugins/ericvrp.bar-autohide`.
- Adds `{ "id": "ericvrp.bar-autohide" }` to the existing `plugins` array in
  `~/.config/omarchy/shell.json` without replacing other settings.
- Removes the legacy `autohide` development installation and configuration.
- Creates a timestamped backup before changing an existing shell config.
- Restarts the Omarchy shell.

Running the installer again updates the installed development build without
adding a duplicate configuration entry.

Remove the local development installation with:

```bash
./scripts/dev-uninstall.sh
```

The uninstaller removes both current and legacy development installations,
updates the shell configuration, and restarts the shell.

Pass `--no-restart` to either helper when testing configuration changes without
restarting the live shell.

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

Re-run `./scripts/dev-install.sh` after editing the working tree.
