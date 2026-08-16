import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "setup.defaults"
  ipcTarget: "setup.defaults.panel"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property string script: Quickshell.env("HOME") + "/.config/omarchy/plugins/setup.defaults/set-defaults.sh"
  readonly property var categories: [
    { id: "terminal", label: "Terminal", glyph: "" },
    { id: "editor",   label: "Editor",   glyph: "" },
    { id: "browser",  label: "Browser",  glyph: "" },
    { id: "video",    label: "Video",    glyph: "󰕬" },
    { id: "email",    label: "Mail",     glyph: "󰉊" }
  ]

  property string selectedCategory: "browser"
  property string currentDefault: ""

  ListModel { id: appModel }

  readonly property color fg: bar ? bar.foreground : Color.popups.text
  readonly property color bg: Color.popups.background
  readonly property color accent: Color.accent
  readonly property string fontFam: bar ? bar.fontFamily : Style.font.family

  function reloadApps() {
    currentDefault = ""
    appModel.clear()
    getProc.command = ["bash", script, "get", selectedCategory]
    getProc.running = true
    listProc.command = ["bash", script, "list", selectedCategory]
    listProc.running = true
  }

  function parseApps(text) {
    appModel.clear()
    var lines = String(text).split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue
      var parts = line.split("\t")
      appModel.append({ id: parts[0], name: parts[1] || parts[0] })
    }
  }

  function applyApp(appId) {
    setProc.command = ["bash", script, "set", selectedCategory, appId]
    setProc.running = true
  }

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
    }

    ScrollView {
      id: scrollArea
      anchors.fill: parent
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

      Column {
        id: panelColumn
        width: scrollArea.availableWidth
        spacing: Style.space(12)

        // Hero
        Item {
          width: parent.width
          implicitHeight: heroIcon.implicitHeight
          Text {
            id: heroIcon
            text: ""
            color: root.fg
            font.family: root.fontFam
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }
          Column {
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            Text {
              text: "Default Apps"
              color: root.fg
              font.family: root.fontFam
              font.pixelSize: Style.font.title
              font.bold: true
              width: parent.width
            }
            Text {
              text: "Pick any installed app"
              color: Qt.darker(root.fg, 1.4)
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              font.bold: true
              width: parent.width
            }
          }
        }

        PanelSeparator { foreground: root.fg }

        // Category selector
        Row {
          width: parent.width
          spacing: Style.space(8)
          Repeater {
            model: root.categories
            Rectangle {
              required property var modelData
              width: (panelColumn.width - Style.space(8) * 4) / 5
              height: 42
              radius: Style.space(10)
              color: modelData.id === root.selectedCategory
                ? Color.accent
                : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
              border.width: 1
              border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
              Column {
                anchors.centerIn: parent
                spacing: Style.space(1)
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: modelData.glyph
                  color: modelData.id === root.selectedCategory ? bg : root.fg
                  font.family: root.fontFam
                  font.pixelSize: Style.font.title
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: parent.parent.width - Style.space(8)
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideRight
                  text: modelData.label
                  color: modelData.id === root.selectedCategory ? bg : root.fg
                  font.family: root.fontFam
                  font.pixelSize: Style.font.caption
                }
              }
              MouseArea {
                anchors.fill: parent
                onClicked: { root.selectedCategory = modelData.id; root.reloadApps() }
              }
            }
          }
        }

        PanelSeparator { foreground: root.fg }

        // App list
        Column {
          width: parent.width
          spacing: Style.space(4)
          Repeater {
            model: appModel
            Rectangle {
              required property var modelData
              width: parent.width
              height: 38
              radius: Style.space(8)
              color: modelData.id === root.currentDefault
                ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
                : "transparent"
              border.width: modelData.id === root.currentDefault ? 1 : 0
              border.color: Color.accent
              Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Style.space(12)
                text: modelData.name
                color: modelData.id === root.currentDefault ? Color.accent : root.fg
                font.family: root.fontFam
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                width: parent.width - (check.visible ? 44 : 24)
              }
              Text {
                id: check
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Style.space(12)
                text: "✓"
                color: Color.accent
                font.family: root.fontFam
                font.pixelSize: Style.font.body
                visible: modelData.id === root.currentDefault
              }
              MouseArea {
                anchors.fill: parent
                onClicked: root.applyApp(modelData.id)
              }
            }
          }
          Text {
            width: parent.width
            text: appModel.count === 0 ? "No installed apps detected for this category." : ""
            color: Qt.darker(root.fg, 1.4)
            font.family: root.fontFam
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          // Fixed bottom spacer so the breathing room below the last entry is
          // equal across categories regardless of how many defaults exist.
          Item {
            width: parent.width
            implicitHeight: Style.space(12)
          }
        }
      }
    }
  }

  Process {
    id: listProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseApps(text)
    }
  }

  Process {
    id: getProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { if (String(text).trim().length > 0) root.currentDefault = String(text).trim() }
    }
  }

  Process {
    id: setProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { root.currentDefault = ""; getProc.command = ["bash", script, "get", root.selectedCategory]; getProc.running = true }
    }
  }

  Component.onCompleted: root.reloadApps()
}
