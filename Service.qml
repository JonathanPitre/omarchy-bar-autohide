import Quickshell
import Quickshell.Io
import QtQuick
import qs.Commons

Item {
  id: root

  readonly property int revealDistance: 0
  readonly property int closeDistance: shell && shell.bar ? shell.bar.barSize : 0
  readonly property int hideDelayMs: 100

  property string configHome: Quickshell.env("XDG_CONFIG_HOME")
    ? Quickshell.env("XDG_CONFIG_HOME")
    : Quickshell.env("HOME") + "/.config"
  property string toggleDir: Quickshell.env("HOME") + "/.local/state/omarchy/toggles"
  property string barOffFile: toggleDir + "/bar-off"
  property string cursorPoller: configHome + "/omarchy/plugins/autohide/cursor_poll.py"
  property var shell: null
  property var hideAtTime: 0

  function hideBar() {
    if (shell && shell.bar && shell.bar.activePopout) {
      root.hideAtTime = Date.now() + root.hideDelayMs
      return
    }
    Util.execDetached("touch " + Util.shellQuote(barOffFile))
  }

  function showBar() {
    root.hideAtTime = 0
    if (shell && shell.bar && shell.bar.barHidden)
      Util.execDetached("rm -f " + Util.shellQuote(barOffFile))
  }

  function distanceFromBarEdge(cursorX, cursorY, monitorWidth, monitorHeight) {
    var position = shell && shell.bar ? shell.bar.position : "top"
    if (position === "bottom") return monitorHeight - 1 - cursorY
    if (position === "left") return cursorX
    if (position === "right") return monitorWidth - 1 - cursorX
    return cursorY
  }

  Process {
    running: true
    command: ["python3", root.cursorPoller]
    stdout: SplitParser {
      onRead: function(line) {
        var fields = String(line).trim().split(",")
        if (fields.length !== 4) return
        var cursorX = Number(fields[0])
        var cursorY = Number(fields[1])
        var monitorWidth = Number(fields[2])
        var monitorHeight = Number(fields[3])
        if (!isFinite(cursorX) || !isFinite(cursorY)
            || !isFinite(monitorWidth) || !isFinite(monitorHeight)) return
        var edgeDistance = root.distanceFromBarEdge(
          cursorX, cursorY, monitorWidth, monitorHeight)

        if (edgeDistance <= root.revealDistance) {
          root.showBar()
        } else if (edgeDistance <= root.closeDistance) {
          root.hideAtTime = 0
        } else if (!root.hideAtTime && shell && shell.bar && !shell.bar.barHidden) {
          root.hideAtTime = Date.now() + root.hideDelayMs
        }

        if (root.hideAtTime && Date.now() >= root.hideAtTime) {
          root.hideAtTime = 0
          root.hideBar()
        }
      }
    }
  }

  Component.onCompleted: {
    Util.execDetached("mkdir -p " + Util.shellQuote(toggleDir)
      + " && touch " + Util.shellQuote(barOffFile))
  }
}
