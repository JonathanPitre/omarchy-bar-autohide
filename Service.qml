import Quickshell
import Quickshell.Io
import QtQuick
import qs.Commons

Item {
  id: root

  readonly property int revealY: 0
  readonly property int closeY: shell && shell.bar ? shell.bar.barSize : 0
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

  Process {
    running: true
    command: ["python3", root.cursorPoller]
    stdout: SplitParser {
      onRead: function(line) {
        var cursorY = Number(String(line).trim())
        if (!isFinite(cursorY)) return

        if (cursorY <= root.revealY) {
          root.showBar()
        } else if (cursorY <= root.closeY) {
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
