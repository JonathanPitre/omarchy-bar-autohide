import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons

Item {
  id: root

  readonly property int revealThickness: 1
  readonly property int hideDelayMs: 200

  property string toggleDir: Quickshell.env("HOME") + "/.local/state/omarchy/toggles"
  property string barOffFile: toggleDir + "/bar-off"
  property var shell: null
  property bool initialBarHidden: false
  property bool initialStateCaptured: false
  property bool autoRevealed: false
  property bool edgeHovered: false
  property var barHoverObservers: []
  property bool barSurfaceHovered: false
  property bool pointerInBarBand: false
  readonly property var bar: shell ? shell.bar : null
  readonly property string position: bar ? bar.position : "top"
  readonly property bool vertical: position === "left" || position === "right"
  readonly property bool barHidden: bar ? bar.barHidden : true
  readonly property bool centerSectionHovered: bar && "centerSectionHovered" in bar
    ? bar.centerSectionHovered : false
  readonly property bool barHovered: barSurfaceHovered || centerSectionHovered || pointerInBarBand
  // Omarchy 4.0.3+ injects PluginBarStateApi (scalars only) into third-party
  // services. `undefined !== null` is true, so the old check pinned the bar open.
  readonly property bool popoutOpen: !!(bar && bar.activePopout)
  readonly property bool canObserveBarSurfaces: !!(bar && "data" in bar)
  // The host's toggles-dir watch can stop delivering events after quick
  // successive flag changes (see Bar.qml's syncHidden). Nudge it so the bar's
  // hidden probe re-reads the flag after each write.
  readonly property string barSyncNudge: " && omarchy-shell -q omarchy.bar syncHidden"

  onBarSurfaceHoveredChanged: {
    if (bar && typeof bar.setCenterSectionHovered === "function")
      bar.setCenterSectionHovered(barSurfaceHovered)
  }

  function refreshBarSurfaceHovered() {
    for (const observer of barHoverObservers) {
      if (observer && observer.hovered) {
        barSurfaceHovered = true
        return
      }
    }
    barSurfaceHovered = false
  }

  function removeBarHoverObserver(observer) {
    barHoverObservers = barHoverObservers.filter(candidate => candidate !== observer)
    refreshBarSurfaceHovered()
  }

  function observeBarPanels() {
    if (!bar || !("data" in bar)) return

    const observedWindows = barHoverObservers.map(observer => observer.observedWindow)
    for (let i = 0; i < bar.data.length; ++i) {
      const variants = bar.data[i]
      if (!variants || !("instances" in variants)) continue

      for (let j = 0; j < variants.instances.length; ++j) {
        const window = variants.instances[j]
        if (!window || !("contentItem" in window) || !("screen" in window)
            || "ghostScreen" in window || observedWindows.includes(window)) continue

        const observer = barHoverObserverComponent.createObject(window.contentItem, {
          "observedWindow": window
        })
        if (observer) {
          barHoverObservers = barHoverObservers.concat([observer])
          observedWindows.push(window)
        }
      }
    }
  }

  function cursorInBarBand(px, py) {
    const size = Math.max(1, (bar && bar.barSize) || 30)
    const screens = Quickshell.screens || []
    for (let i = 0; i < screens.length; ++i) {
      const s = screens[i]
      if (!s) continue
      const sx = Number(s.x || 0)
      const sy = Number(s.y || 0)
      const sw = Number(s.width || 0)
      const sh = Number(s.height || 0)
      if (sw <= 0 || sh <= 0) continue
      if (px < sx || px >= sx + sw || py < sy || py >= sy + sh) continue
      if (position === "top") return py < sy + size
      if (position === "bottom") return py >= sy + sh - size
      if (position === "left") return px < sx + size
      if (position === "right") return px >= sx + sw - size
    }
    return false
  }

  function hideBar() {
    if (!root.autoRevealed || !bar || bar.barHidden
        || root.edgeHovered || root.barHovered || root.popoutOpen) return
    root.autoRevealed = false
    root.pointerInBarBand = false
    Util.execDetached("touch " + Util.shellQuote(barOffFile) + barSyncNudge)
  }

  function showBar() {
    if (bar && bar.barHidden) {
      // The cursor probe path needs a seed while the reveal is sampled.
      // Event-based hosts already track the bar surface directly.
      if (!root.canObserveBarSurfaces)
        root.pointerInBarBand = true
      root.autoRevealed = true
      Util.execDetached("rm -f " + Util.shellQuote(barOffFile) + barSyncNudge)
    }
  }

  Process {
    id: initialStateProbe

    running: true
    command: ["bash", "-c", "[[ -f " + Util.shellQuote(root.barOffFile)
      + " ]] && echo hidden || echo visible"]
    stdout: SplitParser {
      onRead: function(line) {
        root.initialBarHidden = String(line).trim() === "hidden"
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      root.initialStateCaptured = true
      Util.execDetached("mkdir -p " + Util.shellQuote(root.toggleDir)
        + " && touch " + Util.shellQuote(root.barOffFile) + barSyncNudge)
      Qt.callLater(root.observeBarPanels)
    }
  }

  Process {
    id: cursorProbe

    running: false
    command: ["hyprctl", "cursorpos"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (!root.autoRevealed || root.barHidden) return
        const text = String(this.text || "").trim()
        const parts = text.split(",")
        const px = Number(parts[0])
        const py = Number(parts[1])
        // A sample without a position carries no answer. The next probe either
        // restores the state or confirms the exit; never run on stale data.
        if (parts.length < 2 || Number.isNaN(px) || Number.isNaN(py)) {
          root.pointerInBarBand = false
          return
        }
        root.pointerInBarBand = root.cursorInBarBand(px, py)
      }
    }
  }

  Timer {
    interval: 80
    repeat: true
    running: root.autoRevealed && !root.barHidden && !root.canObserveBarSurfaces
    onTriggered: {
      if (!cursorProbe.running)
        cursorProbe.running = true
    }
    onRunningChanged: {
      if (!running)
        root.pointerInBarBand = false
    }
  }

  Timer {
    interval: root.hideDelayMs
    running: root.autoRevealed && !root.barHidden
      && !root.edgeHovered && !root.barHovered && !root.popoutOpen
    onTriggered: root.hideBar()
  }

  Connections {
    target: root.bar
    function onBarHiddenChanged() {
      if (root.barHidden) {
        root.autoRevealed = false
        root.pointerInBarBand = false
      }
    }
  }

  Connections {
    target: Quickshell
    function onScreensChanged() { Qt.callLater(root.observeBarPanels) }
  }

  Component {
    id: barHoverObserverComponent

    Item {
      required property var observedWindow
      readonly property alias hovered: wholeBarHover.hovered

      anchors.fill: parent
      z: 1000000

      HoverHandler {
        id: wholeBarHover
        blocking: false
        onHoveredChanged: root.refreshBarSurfaceHovered()
      }

      Component.onDestruction: root.removeBarHoverObserver(this)
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        required property var modelData

        screen: modelData
        visible: root.barHidden || root.autoRevealed
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: root.vertical ? root.revealThickness : 0
        implicitHeight: root.vertical ? 0 : root.revealThickness

        anchors {
          top: root.position === "top" || root.vertical
          bottom: root.position === "bottom" || root.vertical
          left: root.position === "left" || !root.vertical
          right: root.position === "right" || !root.vertical
        }

        WlrLayershell.namespace: "omarchy-bar-autohide-trigger"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        HoverHandler {
          onHoveredChanged: {
            root.edgeHovered = hovered
            if (hovered) root.showBar()
          }
        }
      }
    }
  }

  Component.onDestruction: {
    if (bar && typeof bar.setCenterSectionHovered === "function")
      bar.setCenterSectionHovered(false)
    // Always clean up on unload. If the async probe never finished before
    // teardown, its own restore never ran, so the rm below is the safe
    // default (a no-op when nothing was stranded) instead of leaving
    // bar-off behind to keep the bar stuck hidden.
    if (initialStateCaptured && initialBarHidden) {
      Util.execDetached("mkdir -p " + Util.shellQuote(toggleDir)
        + " && touch " + Util.shellQuote(barOffFile) + barSyncNudge)
    } else {
      Util.execDetached("rm -f " + Util.shellQuote(barOffFile) + barSyncNudge)
    }
  }

  onBarChanged: Qt.callLater(root.observeBarPanels)
}
