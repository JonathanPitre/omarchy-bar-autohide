import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons

Item {
  id: root

  readonly property int revealThickness: 1
  readonly property int hideDelayMs: 1000

  property string toggleDir: Quickshell.env("HOME") + "/.local/state/omarchy/toggles"
  property string barOffFile: toggleDir + "/bar-off"
  property var shell: null
  property bool initialBarHidden: false
  property bool initialStateCaptured: false
  property bool autoRevealed: false
  property bool edgeHovered: false
  property var barHoverObservers: []
  property bool barSurfaceHovered: false
  readonly property var bar: shell ? shell.bar : null
  readonly property string position: bar ? bar.position : "top"
  readonly property bool vertical: position === "left" || position === "right"
  readonly property bool barHidden: bar ? bar.barHidden : true
  readonly property bool centerSectionHovered: bar && "centerSectionHovered" in bar
    ? bar.centerSectionHovered : false
  readonly property bool barHovered: barSurfaceHovered || centerSectionHovered
  readonly property bool popoutOpen: bar && bar.activePopout !== null

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

  function hideBar() {
    if (!root.autoRevealed || !bar || bar.barHidden
        || root.edgeHovered || root.barHovered || root.popoutOpen) return
    root.autoRevealed = false
    Util.execDetached("touch " + Util.shellQuote(barOffFile))
  }

  function showBar() {
    if (bar && bar.barHidden) {
      root.autoRevealed = true
      Util.execDetached("rm -f " + Util.shellQuote(barOffFile))
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
        + " && touch " + Util.shellQuote(root.barOffFile))
      Qt.callLater(root.observeBarPanels)
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
      if (root.barHidden) root.autoRevealed = false
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
    if (!initialStateCaptured) return
    if (initialBarHidden) {
      Util.execDetached("mkdir -p " + Util.shellQuote(toggleDir)
        + " && touch " + Util.shellQuote(barOffFile))
    } else {
      Util.execDetached("rm -f " + Util.shellQuote(barOffFile))
    }
  }

  onBarChanged: Qt.callLater(root.observeBarPanels)
}
