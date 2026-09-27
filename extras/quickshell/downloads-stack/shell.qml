// macOS-style Downloads "stack": a frosted grid of the newest files in
// ~/Downloads that pops up above the dock. Launched (and toggled) by
// ~/.local/bin/downloads-stack, which passes placement via STACK_* env vars.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: root

  readonly property string downloadsDir: Quickshell.env("STACK_DIR") || Quickshell.env("HOME") + "/Downloads"
  readonly property int centerX: parseInt(Quickshell.env("STACK_CENTER_X") || "0")
  readonly property int screenW: parseInt(Quickshell.env("STACK_SCREEN_W") || "0")
  readonly property int bottomGap: parseInt(Quickshell.env("STACK_BOTTOM") || "72")

  readonly property int columns: 4
  readonly property int maxRows: 3
  readonly property int cellW: 96
  readonly property int cellH: 104

  // Light or dark palette, chosen by ~/.local/bin/downloads-stack from the theme.
  readonly property bool dark: Quickshell.env("STACK_DARK") === "1"
  readonly property color panelColor: dark ? Qt.rgba(0.17, 0.17, 0.18, 0.82) : Qt.rgba(0.965, 0.965, 0.965, 0.82)
  readonly property color panelBorder: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12)
  readonly property color textColor: dark ? "#e5e5e7" : "#1d1d1f"
  readonly property color secondaryText: dark ? "#98989d" : "#6e6e73"
  readonly property color hoverTint: dark ? "#ffffff" : "#000000"
  readonly property color linkColor: dark ? "#0a84ff" : "#007aff"
  readonly property color linkHover: dark ? "#409cff" : "#0060df"

  property var files: []
  property bool loaded: false

  function close() { Qt.quit() }

  function openPath(path) {
    Quickshell.execDetached(["xdg-open", path])
    close()
  }

  function iconFor(mime) {
    if (mime === "inode/directory") return Quickshell.iconPath("folder")
    return Quickshell.iconPath(mime.replace("/", "-"), true)
        || Quickshell.iconPath(mime.split("/")[0] + "-x-generic", true)
        || Quickshell.iconPath("text-x-generic")
  }

  // Newest first; skip hidden files and in-progress browser downloads.
  Process {
    running: true
    command: ["bash", "-c",
      "find \"$1\" -mindepth 1 -maxdepth 1 ! -name '.*' ! -name '*.part' ! -name '*.crdownload' "
      + "-printf '%T@\\t%p\\n' | sort -rn | head -n 24 | cut -f2- | "
      + "while IFS= read -r f; do printf '%s\\t%s\\n' \"$f\" \"$(file --mime-type -b -- \"$f\")\"; done",
      "_", root.downloadsDir]
    stdout: StdioCollector {
      onStreamFinished: {
        root.files = this.text.split("\n").filter(l => l.length).map(l => {
          const [path, mime] = l.split("\t")
          return { path, mime, name: path.substring(path.lastIndexOf("/") + 1) }
        })
        root.loaded = true
      }
    }
  }

  PanelWindow {
    id: win

    screen: {
      const wanted = Quickshell.env("STACK_MONITOR")
      for (const s of Quickshell.screens) if (s.name === wanted) return s
      return Quickshell.screens[0]
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "downloads-stack"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Clicking anywhere outside the stack (including the dock icon) closes it.
    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    Item {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.close()
    }

    Item {
      id: stack

      readonly property int rows: Math.max(1, Math.min(root.maxRows, Math.ceil(root.files.length / root.columns)))
      readonly property int w: root.columns * root.cellW + 24
      readonly property int w0: root.screenW || win.width

      width: w
      height: 44 + (root.files.length ? rows * root.cellH : 90) + 44
      x: Math.max(8, Math.min(w0 - w - 8, root.centerX - w / 2))
      y: win.height - root.bottomGap - height

      // Pop up from the dock icon.
      transformOrigin: Item.Bottom
      scale: root.loaded ? 1 : 0.85
      opacity: root.loaded ? 1 : 0
      Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
      Behavior on opacity { NumberAnimation { duration: 120 } }

      // Swallow clicks inside the panel so they don't close it.
      MouseArea { anchors.fill: parent }

      // Little arrow pointing down at the dock icon.
      Rectangle {
        width: 16; height: 16
        rotation: 45
        color: panel.color
        border.color: panel.border.color
        x: Math.max(20, Math.min(stack.width - 36, root.centerX - stack.x - 8))
        y: stack.height - 11
      }

      Rectangle {
        id: panel
        anchors.fill: parent
        radius: 14
        color: root.panelColor
        border.color: root.panelBorder
        border.width: 1

        Text {
          id: title
          text: "Downloads"
          font { family: "Inter Variable"; pixelSize: 15; weight: Font.DemiBold }
          color: root.textColor
          anchors { top: parent.top; topMargin: 14; horizontalCenter: parent.horizontalCenter }
        }

        Text {
          visible: root.loaded && !root.files.length
          text: "No downloads yet"
          font { family: "Inter Variable"; pixelSize: 13 }
          color: root.secondaryText
          anchors.centerIn: parent
        }

        GridView {
          id: grid
          anchors { top: title.bottom; topMargin: 10; left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12; bottom: footer.top; bottomMargin: 4 }
          cellWidth: root.cellW
          cellHeight: root.cellH
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: root.files

          delegate: Item {
            id: cell
            required property var modelData
            width: root.cellW
            height: root.cellH

            Rectangle {
              anchors { fill: parent; margins: 3 }
              radius: 8
              color: hover.containsMouse ? Qt.rgba(root.hoverTint.r, root.hoverTint.g, root.hoverTint.b, hover.pressed ? 0.14 : 0.07) : "transparent"
            }

            Image {
              id: thumb
              anchors { top: parent.top; topMargin: 8; horizontalCenter: parent.horizontalCenter }
              width: 52; height: 52
              sourceSize { width: 104; height: 104 }
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              source: cell.modelData.mime.startsWith("image/") && cell.modelData.mime !== "image/svg+xml"
                ? "file://" + cell.modelData.path
                : root.iconFor(cell.modelData.mime)
              onStatusChanged: if (status === Image.Error) source = root.iconFor(cell.modelData.mime)
            }

            Text {
              anchors { top: thumb.bottom; topMargin: 6; left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6 }
              text: cell.modelData.name
              font { family: "Inter Variable"; pixelSize: 11 }
              color: root.textColor
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WrapAnywhere
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            MouseArea {
              id: hover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openPath(cell.modelData.path)
            }
          }
        }

        Rectangle {
          id: footer
          anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 1 }
          height: 40
          color: "transparent"

          Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1
            color: Qt.rgba(root.hoverTint.r, root.hoverTint.g, root.hoverTint.b, 0.08)
          }

          Text {
            anchors.centerIn: parent
            text: "Open in Files  ›"
            font { family: "Inter Variable"; pixelSize: 13; weight: Font.Medium }
            color: footerArea.containsMouse ? root.linkHover : root.linkColor
          }

          MouseArea {
            id: footerArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              Quickshell.execDetached(["nautilus", root.downloadsDir])
              root.close()
            }
          }
        }
      }
    }
  }
}
