// macOS-style "genie" minimize/restore animation.
//
// A resident Quickshell daemon (started from ~/.config/hypr/macos/autostart.lua).
// ~/.local/bin/genie snapshots the window and calls in over IPC with the
// window's rect and its dock icon's position; we play the warp on a
// click-through overlay while the real window is hidden/restored underneath.
//
//   qs -p ~/.config/quickshell/genie ipc call genie minimize <addr> <png> <monitor> <x> <y> <w> <h> <iconX> <iconY>
//   qs -p ~/.config/quickshell/genie ipc call genie restore  <addr> <png> <monitor> <x> <y> <w> <h> <iconX> <iconY>
//
// All coordinates are logical pixels relative to the monitor.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: root

  readonly property int bendMs: 230
  readonly property int slideMs: 330

  property string mode: ""       // "minimize" | "restore" | ""
  property string address: ""
  property string monitorName: ""
  property rect win: Qt.rect(0, 0, 1, 1)
  property point icon: Qt.point(0, 0)

  function dispatch(cmd) {
    Quickshell.execDetached(["hyprctl", "dispatch", cmd])
  }

  function start(newMode, addr, png, monitor, x, y, w, h, iconX, iconY) {
    // A request arriving mid-animation finishes the previous one first.
    if (anim.running) anim.complete()

    mode = newMode
    address = addr
    monitorName = monitor
    win = Qt.rect(x, y, w, h)
    icon = Qt.point(iconX, iconY)

    genie.bend = mode === "minimize" ? 0 : 1
    genie.slide = mode === "minimize" ? 0 : 1
    genie.opacity = mode === "minimize" ? 1 : 0

    snapshot.source = ""
    snapshot.source = "file://" + png
  }

  // Runs once the snapshot is decoded and on screen.
  function play() {
    overlay.visible = true
    if (mode === "minimize") {
      // Give the overlay a frame to cover the window before hiding it.
      hideWindow.restart()
    } else {
      anim.restart()
    }
  }

  function finished() {
    if (mode === "restore") {
      dispatch(`function() genie_finish_restore('${address}') end`)
      // Keep the last frame up until the real window has been drawn back.
      hideOverlay.restart()
    } else {
      overlay.visible = false
    }
    mode = ""
  }

  IpcHandler {
    target: "genie"

    function minimize(addr: string, png: string, monitor: string, x: int, y: int, w: int, h: int, iconX: int, iconY: int): void {
      root.start("minimize", addr, png, monitor, x, y, w, h, iconX, iconY)
    }

    function restore(addr: string, png: string, monitor: string, x: int, y: int, w: int, h: int, iconX: int, iconY: int): void {
      root.start("restore", addr, png, monitor, x, y, w, h, iconX, iconY)
    }
  }

  Timer {
    id: hideWindow
    interval: 34
    onTriggered: {
      root.dispatch(`hl.dsp.window.move({ workspace = 'special:minimized', follow = false, window = 'address:${root.address}' })`)
      anim.restart()
    }
  }

  Timer {
    id: hideOverlay
    interval: 60
    onTriggered: overlay.visible = false
  }

  // Minimize: bend the window into the funnel, then slide it down into the
  // icon, fading at the very end. Restore plays the exact mirror image.
  readonly property bool minimizing: mode === "minimize"
  readonly property int slideStart: bendMs * 0.45
  readonly property int totalMs: slideStart + slideMs

  SequentialAnimation {
    id: anim

    ParallelAnimation {
      SequentialAnimation {
        PauseAnimation { duration: root.minimizing ? 0 : root.totalMs - root.bendMs }
        NumberAnimation {
          target: genie; property: "bend"
          to: root.minimizing ? 1 : 0
          duration: root.bendMs
          easing.type: Easing.InOutSine
        }
      }
      SequentialAnimation {
        PauseAnimation { duration: root.minimizing ? root.slideStart : 0 }
        NumberAnimation {
          target: genie; property: "slide"
          to: root.minimizing ? 1 : 0
          duration: root.slideMs
          easing.type: root.minimizing ? Easing.InCubic : Easing.OutCubic
        }
      }
      SequentialAnimation {
        PauseAnimation { duration: root.minimizing ? root.totalMs - root.slideMs * 0.3 : 0 }
        NumberAnimation {
          target: genie; property: "opacity"
          to: root.minimizing ? 0 : 1
          duration: root.slideMs * 0.3
        }
      }
    }

    ScriptAction { script: root.finished() }
  }

  PanelWindow {
    id: overlay
    visible: false

    screen: {
      for (const s of Quickshell.screens) if (s.name === root.monitorName) return s
      return Quickshell.screens[0]
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "genie"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}  // click-through

    Image {
      id: snapshot
      visible: false
      cache: false
      asynchronous: false
      onStatusChanged: if (status === Image.Ready && root.mode !== "") root.play()
    }

    ShaderEffect {
      id: genie
      x: root.win.x
      y: root.win.y
      width: root.win.width
      height: root.win.height

      property var source: snapshot
      property real bend: 0
      property real slide: 0
      property real targetX: root.icon.x - root.win.x
      property real targetY: Math.max(root.icon.y - root.win.y, root.win.height + 1)
      property real itemW: width
      property real itemH: height
      property real iconW: 40
      property real radius: 12

      mesh: GridMesh { resolution: Qt.size(4, 64) }
      vertexShader: "shaders/genie.vert.qsb"
      fragmentShader: "shaders/genie.frag.qsb"
    }
  }
}
