pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omaven"

  // Bar coordination properties
  readonly property bool opened: panelItem ? panelItem.opened === true : false
  function open() { if (panelItem) panelItem.open() }
  function close() { if (panelItem) panelItem.close() }
  function togglePanel() { if (panelItem) panelItem.toggle() }

  readonly property bool popoutSwitchClosing: panelItem ? panelItem.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelItem) panelItem.closeForPopoutSwitch() }

  property var panelItem: null

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    panelItem = target
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("client" in target) target.client = avenClient
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  AvenClient {
    id: avenClient
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("PopupPanel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "omaven"

    function refresh(): void { avenClient.refresh() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function sync(): void { avenClient.triggerSync() }
    function openWindow(): void {
      if (root.bar) {
        root.bar.run("omarchy-shell shell summon omaven \"{}\"")
      }
    }
  }

  function summonDesktopWindow() {
    if (root.bar) {
      root.bar.run("omarchy-shell shell toggle omaven")
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰄲"
    slotSize: Style.bar.statusSlot
    tooltipText: {
      var op = avenClient.counts.open || 0
      var act = avenClient.counts.active || 0
      var td = avenClient.counts.todo || 0
      var bl = avenClient.counts.backlog || 0
      var st = avenClient.syncing ? "Syncing..." : (avenClient.syncInfo.state || "Ready")
      return "Omaven · " + op + " open (" + act + " active, " + td + " todo, " + bl + " backlog)\nStatus: " + st + "\nClick: Quick Popup · Middle-Click: Desktop Window · Right-Click: Sync"
    }

    onPressed: function(b) {
      if (b === Qt.LeftButton) {
        root.togglePanel()
      } else if (b === Qt.MiddleButton) {
        root.summonDesktopWindow()
      } else if (b === Qt.RightButton) {
        avenClient.triggerSync()
      }
    }
  }

  // Open tasks badge count
  Rectangle {
    id: badge
    visible: (avenClient.counts.open || 0) > 0
    anchors.top: button.top
    anchors.right: button.right
    anchors.topMargin: Style.space(2)
    anchors.rightMargin: Style.space(2)
    z: 10

    readonly property int openCount: avenClient.counts.open || 0
    readonly property bool hasUrgent: (avenClient.counts.urgent || 0) > 0
    readonly property bool hasHigh: (avenClient.counts.high || 0) > 0

    implicitWidth: Math.max(Style.space(14), badgeText.implicitWidth + Style.space(6))
    implicitHeight: Style.space(14)
    radius: height / 2
    color: hasUrgent ? "#ef4444" : (hasHigh ? "#f97316" : Commons.Color.accent)
    border.width: 1
    border.color: root.bar ? root.bar.background : "transparent"

    Text {
      id: badgeText
      anchors.centerIn: parent
      text: badge.openCount > 99 ? "99+" : String(badge.openCount)
      color: "white"
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption * 0.8
      font.bold: true
    }
  }

  // Syncing indicator dot/spinner
  Rectangle {
    id: syncDot
    visible: avenClient.syncing
    anchors.bottom: button.bottom
    anchors.right: button.right
    anchors.bottomMargin: Style.space(3)
    anchors.rightMargin: Style.space(3)
    width: Style.space(6)
    height: Style.space(6)
    radius: width / 2
    color: "#3b82f6"
    z: 11

    SequentialAnimation on opacity {
      running: avenClient.syncing
      loops: Animation.Infinite
      NumberAnimation { from: 0.3; to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
      NumberAnimation { from: 1.0; to: 0.3; duration: 400; easing.type: Easing.InOutQuad }
    }
  }
}
