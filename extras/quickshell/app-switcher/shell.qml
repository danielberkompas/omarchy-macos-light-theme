// macOS-style ⌘Tab app switcher.
//
// A resident Quickshell daemon (started from ~/.config/hypr/macos/autostart.lua)
// that only draws the switcher. ~/.config/hypr/macos/switcher.lua owns the
// keys and decides what's selected; it talks to us with Hyprland custom events:
//
//   switcher show <light|dark> <index> <address>=<class> <address>=<class> …
//   switcher select <index>
//   switcher hide
//
// Indexes are 1-based; classes have spaces and "%" percent-encoded.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
  id: root

  property var items: []  // [{ address, name, icon }]
  property int index: 0   // 0-based
  property bool dark: false
  property bool open: false
  property var screen: null

  function iconFor(entry, cls) {
    if (entry && entry.icon) return Quickshell.iconPath(entry.icon, "application-x-executable")
    if (/terminal/i.test(cls)) return Quickshell.iconPath("utilities-terminal", "application-x-executable")
    return Quickshell.iconPath(cls.toLowerCase(), "application-x-executable")
  }

  function nameFor(entry, cls) {
    if (entry && entry.name) return entry.name
    const last = cls.split(".").pop()
    return last.charAt(0).toUpperCase() + last.slice(1)
  }

  function show(mode, selected, pairs) {
    const list = []
    for (const pair of pairs) {
      const at = pair.indexOf("=")
      const address = pair.slice(0, at)
      const cls = decodeURIComponent(pair.slice(at + 1))
      let entry = null
      try { entry = DesktopEntries.heuristicLookup(cls) } catch (e) { entry = null }
      list.push({ address: address, name: nameFor(entry, cls), icon: iconFor(entry, cls) })
    }
    const monitor = Hyprland.focusedMonitor
    screen = Quickshell.screens.find(s => monitor && s.name === monitor.name) || Quickshell.screens[0]
    dark = mode === "dark"
    items = list
    index = selected - 1
    // Like macOS, a quick ⌘Tab tap switches without flashing the switcher.
    showDelay.restart()
  }

  function hide() {
    showDelay.stop()
    open = false
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name !== "custom") return
      const parts = event.data.split(" ")
      if (parts[0] !== "switcher") return
      if (parts[1] === "show") root.show(parts[2], parseInt(parts[3]), parts.slice(4))
      else if (parts[1] === "select") root.index = parseInt(parts[2]) - 1
      else if (parts[1] === "hide") root.hide()
    }
  }

  Timer {
    id: showDelay
    interval: 120
    onTriggered: root.open = true
  }

  PanelWindow {
    id: overlay
    visible: root.open
    screen: root.screen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "app-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Shrink the icons if there are too many to fit across the screen.
    readonly property int padding: 14
    readonly property int spacing: 6
    readonly property real maxWidth: (root.screen ? root.screen.width : 1200) * 0.9
    readonly property int cell: Math.max(40, Math.min(104,
      Math.floor((maxWidth - 2 * padding) / Math.max(1, root.items.length)) - spacing))
    readonly property int iconSize: Math.round(cell * 0.8)

    implicitWidth: row.width + 2 * padding
    implicitHeight: cell + 2 * padding + 26

    Rectangle {
      anchors.fill: parent
      radius: 24
      color: root.dark ? Qt.rgba(0.14, 0.14, 0.15, 0.62) : Qt.rgba(0.97, 0.97, 0.97, 0.62)
      border.width: 1
      border.color: root.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)

      Row {
        id: row
        x: overlay.padding
        y: overlay.padding
        spacing: overlay.spacing

        Repeater {
          model: root.items

          Item {
            required property var modelData
            required property int index
            readonly property bool selected: index === root.index
            width: overlay.cell
            height: overlay.cell + 26

            Rectangle {
              width: overlay.cell
              height: overlay.cell
              radius: 14
              color: root.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.1)
              visible: parent.selected
            }

            IconImage {
              x: (overlay.cell - overlay.iconSize) / 2
              y: (overlay.cell - overlay.iconSize) / 2
              implicitSize: overlay.iconSize
              source: modelData.icon
              asynchronous: false
            }

            Text {
              visible: parent.selected
              anchors.horizontalCenter: parent.horizontalCenter
              y: overlay.cell + 5
              text: modelData.name
              color: root.dark ? "#f2f2f7" : "#1c1c1e"
              font.family: "Inter Variable"
              font.pixelSize: 13
              font.weight: Font.Medium
            }

            MouseArea {
              anchors.fill: parent
              onClicked: Quickshell.execDetached(["hyprctl", "dispatch",
                `function() app_switcher_pick(${index + 1}) end`])
            }
          }
        }
      }
    }
  }
}
