// macOS "traffic light" buttons for Chromium, which has no title bar
// (see ~/.config/hypr/macos/titlebars.lua).
//
// Chromium draws its own close/minimize/maximize buttons in the tab strip, but
// Hyprland ignores its minimize and maximize requests (minimize even freezes
// it). So this daemon covers those buttons with red/yellow/green dots that do
// the same things as the hyprbars buttons on every other window. The patch
// behind the dots is filled with the tab strip's colour, sampled from screen
// once per focus state and again whenever Omarchy changes Chromium's theme.
//
// Launched on login from ~/.config/hypr/macos/autostart.lua.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
  id: root

  readonly property var chromeClass: /^(chromium|google-chrome)$/

  // Geometry of the patch over Chromium's own buttons, relative to the window.
  readonly property int patchX: 8
  readonly property int patchY: 6
  readonly property int patchW: 92
  readonly property int patchH: 28
  // Dots mirror hyprbars: 12px, 12px in from the edge, 8px apart.
  readonly property int dotSize: 12
  readonly property int dotGap: 8
  readonly property int dotInset: 12 - patchX
  // Where to sample the tab strip colour: just past the patch, above the tabs.
  readonly property int sampleX: 106
  readonly property int sampleY: 2
  // How long window moves and desktop switches animate (looknfeel.lua).
  readonly property int settleMs: 450
  readonly property int workspaceMs: 650

  property var clients: []
  property var monitors: []
  property string activeAddress: ""
  property var lastRects: ({})      // address -> "x,y,w,h"
  property var settlingUntil: ({})  // address -> ms timestamp
  property real workspaceUntil: 0
  property var colors: ({})         // "active"/"inactive" -> "#rrggbb"
  property int focusChanges: 0      // bumped on every focus change
  property real now: Date.now()
  // Addresses of Chromium windows whose dots should be showing. Only reassigned
  // when it actually changes, so the overlays aren't torn down and rebuilt.
  property var shown: []

  function stateOf(address) {
    return address === activeAddress ? "active" : "inactive"
  }

  function updateShown() {
    const next = computeShown()
    if (next.join() !== shown.join()) shown = next
  }

  function computeShown() {
    const shown = []
    const activeWs = {}
    for (const m of monitors) {
      if (!m.specialWorkspace || !m.specialWorkspace.id) activeWs[m.activeWorkspace.id] = m
    }
    for (const c of clients) {
      if (!chromeClass.test(c.class) || !c.mapped || c.hidden) continue
      if (!activeWs[c.workspace.id] || c.fullscreen === 2) continue
      if ((c.tags || []).some(t => t.startsWith("genie-hidden"))) continue
      if (now < workspaceUntil || now < (settlingUntil[c.address] || 0)) continue
      if (isCovered(c)) continue
      shown.push(c.address)
    }
    return shown
  }

  onNowChanged: updateShown()

  function byAddress(address) {
    return clients.find(c => c.address === address)
  }

  // True when another window is stacked above this one over its buttons.
  function isCovered(c) {
    const x1 = c.at[0] + patchX, y1 = c.at[1] + patchY
    const x2 = x1 + patchW, y2 = y1 + patchH
    return clients.some(o => {
      if (o.address === c.address || o.workspace.id !== c.workspace.id || !o.mapped || o.hidden) return false
      const above = (o.floating && !c.floating)
        || (o.floating === c.floating && o.focusHistoryID < c.focusHistoryID)
      return above && o.at[0] < x2 && o.at[0] + o.size[0] > x1 && o.at[1] < y2 && o.at[1] + o.size[1] > y1
    })
  }

  function dispatch(expr) {
    Quickshell.execDetached(["hyprctl", "dispatch", expr])
  }

  function closeWindow(address) {
    dispatch(`hl.dsp.window.close({ window = 'address:${address}' })`)
  }

  // Straight to the genie helper (what ⌘M runs) rather than focusing the window
  // first, because focusing makes Hyprland warp the pointer.
  function minimizeWindow(address) {
    Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/genie", "minimize", address])
  }

  function maximizeWindow(address) {
    dispatch(`hl.dsp.window.fullscreen({ mode = 'maximized', window = 'address:${address}' })`)
  }

  function refresh() {
    if (!query.running) query.running = true
  }

  // Re-check once the current animations have finished.
  function refreshLater(ms) {
    Qt.callLater(refresh)
    settleTimer.interval = ms + 20
    settleTimer.restart()
  }

  function update(data) {
    const t = Date.now()
    const rects = {}
    const settling = Object.assign({}, settlingUntil)
    let moved = false
    for (const c of data.clients) {
      if (!chromeClass.test(c.class)) continue
      const rect = `${c.at},${c.size}`
      rects[c.address] = rect
      if (lastRects[c.address] !== undefined && lastRects[c.address] !== rect) {
        settling[c.address] = t + settleMs
        moved = true
      }
    }
    lastRects = rects
    settlingUntil = settling
    clients = data.clients
    monitors = data.monitors
    activeAddress = data.active.address || ""
    now = t
    updateShown()
    if (moved) refreshLater(settleMs)
    sampleColors()
  }

  // Learn the tab strip colour for a focus state we haven't seen yet, from a
  // Chromium window that's currently showing in that state.
  function sampleColors() {
    if (sampler.running) return
    for (const a of shown) {
      const state = stateOf(a)
      if (colors[state]) continue
      const c = byAddress(a)
      sampler.state = state
      sampler.generation = focusChanges
      sampler.command = ["bash", "-c",
        "sleep 0.3; grim -g \"$1 1x1\" -t ppm - | magick - -format '%[hex:p{0,0}]' info:",
        "_", `${c.at[0] + sampleX},${c.at[1] + sampleY}`]
      sampler.running = true
      return
    }
  }

  Process {
    id: query
    command: ["bash", "-c",
      "printf '{\"clients\":%s,\"monitors\":%s,\"active\":%s}' "
      + "\"$(hyprctl -j clients)\" \"$(hyprctl -j monitors)\" \"$(hyprctl -j activewindow)\""]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.update(JSON.parse(this.text)) } catch (e) {}
      }
    }
  }

  Process {
    id: sampler
    property string state
    property int generation
    stdout: StdioCollector {
      onStreamFinished: {
        const hex = this.text.trim()
        // Discard it if focus changed while sampling: it may be the other state.
        if (sampler.generation !== root.focusChanges || !/^[0-9A-Fa-f]{6}/.test(hex)) return
        const next = Object.assign({}, root.colors)
        next[sampler.state] = "#" + hex.substring(0, 6)
        root.colors = next
      }
    }
    onExited: Qt.callLater(root.sampleColors)
  }

  // Omarchy rewrites this policy with the theme's colour on every theme change.
  FileView {
    path: "/etc/chromium/policies/managed/color.json"
    watchChanges: true
    onFileChanged: {
      root.colors = {}
      settleTimer.interval = 1500
      settleTimer.restart()
    }
  }

  Timer {
    id: settleTimer
    onTriggered: { root.now = Date.now(); root.refresh() }
  }

  // Catches drag-resizes and anything else that doesn't raise an event.
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      switch (event.name) {
      case "workspacev2":
      case "focusedmonv2":
      case "activespecialv2":
        root.workspaceUntil = Date.now() + root.workspaceMs
        root.refreshLater(root.workspaceMs)
        break
      case "openwindow":
      case "closewindow":
      case "activewindowv2":
        root.focusChanges++
        root.activeAddress = "0x" + event.data
        root.refreshLater(root.settleMs)
        break
      case "movewindowv2":
      case "fullscreen":
      case "changefloatingmode":
      case "configreloaded":
      case "monitoraddedv2":
      case "monitorremovedv2":
        root.refreshLater(root.settleMs)
        break
      }
    }
  }

  Component.onCompleted: refresh()

  Variants {
    model: root.shown

    PanelWindow {
      id: lights
      required property string modelData
      readonly property var client: root.byAddress(modelData)
      readonly property var monitor: client ? root.monitors.find(m => m.id === client.monitor) : null
      readonly property bool hovered: hover.hovered

      screen: {
        for (const s of Quickshell.screens) if (monitor && s.name === monitor.name) return s
        return Quickshell.screens[0]
      }

      anchors { top: true; left: true }
      margins {
        left: client && monitor ? client.at[0] - monitor.x + root.patchX : 0
        top: client && monitor ? client.at[1] - monitor.y + root.patchY : 0
      }
      implicitWidth: root.patchW
      implicitHeight: root.patchH
      color: root.colors[root.stateOf(modelData)] || root.colors.active || "#f4d1e1"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "chrome-lights"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      // Passive, so it keeps tracking while the dots' own MouseAreas take the events.
      HoverHandler {
        id: hover
      }

      Row {
        x: root.dotInset
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.dotGap

        Repeater {
          model: [
            { color: "#ff5f57", fg: "#4d0000", icon: "×", action: "close" },
            { color: "#febc2e", fg: "#5a3d00", icon: "−", action: "minimize" },
            { color: "#28c840", fg: "#003d00", icon: "+", action: "maximize" },
          ]

          Rectangle {
            required property var modelData
            width: root.dotSize
            height: root.dotSize
            radius: width / 2
            color: modelData.color
            border.width: 0.5
            border.color: Qt.darker(modelData.color, 1.15)

            Text {
              anchors.centerIn: parent
              anchors.verticalCenterOffset: -0.5
              text: parent.modelData.icon
              color: parent.modelData.fg
              font.pixelSize: 11
              font.weight: Font.Bold
              visible: lights.hovered
            }

            MouseArea {
              anchors.fill: parent
              anchors.margins: -3
              onClicked: {
                const a = lights.modelData
                if (parent.modelData.action === "close") root.closeWindow(a)
                else if (parent.modelData.action === "minimize") root.minimizeWindow(a)
                else root.maximizeWindow(a)
              }
            }
          }
        }
      }
    }
  }
}
