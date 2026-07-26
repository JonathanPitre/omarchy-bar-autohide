#!/usr/bin/env python3

import json
import os
import socket
import time


POLL_INTERVAL_SECONDS = 0.05
MONITOR_REFRESH_SECONDS = 5

RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", "")
INSTANCE = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
SOCKET_PATH = os.path.join(RUNTIME_DIR, "hypr", INSTANCE, ".socket.sock")


def request(command):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(0.5)
        client.connect(SOCKET_PATH)
        client.sendall(("j/" + command).encode())
        chunks = []
        while True:
            chunk = client.recv(4096)
            if not chunk:
                break
            chunks.append(chunk)
    return json.loads(b"".join(chunks))


def monitor_geometry(monitor):
    scale = monitor.get("scale") or 1
    width = monitor.get("width", 0) / scale
    height = monitor.get("height", 0) / scale
    transform = monitor.get("transform", 0)
    if transform in (1, 3, 5, 7):
        width, height = height, width
    return monitor.get("x", 0), monitor.get("y", 0), width, height


def monitor_at(monitors, x, y):
    for monitor in monitors:
        if monitor.get("disabled"):
            continue
        left, top, width, height = monitor_geometry(monitor)
        if left <= x < left + width and top <= y < top + height:
            return monitor
    return None


def main():
    monitors = []
    monitors_refreshed_at = 0

    while True:
        try:
            now = time.monotonic()
            if not monitors or now - monitors_refreshed_at >= MONITOR_REFRESH_SECONDS:
                monitors = request("monitors")
                monitors_refreshed_at = now

            position = request("cursorpos")
            monitor = monitor_at(monitors, position["x"], position["y"])
            if monitor:
                left, top, width, height = monitor_geometry(monitor)
                print(
                    f"{position['x'] - left},{position['y'] - top},{width},{height}",
                    flush=True,
                )
        except (KeyError, OSError, ValueError):
            pass
        time.sleep(POLL_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
