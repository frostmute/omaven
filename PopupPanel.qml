pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "omaven"
  ipcTarget: "omaven"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property var client: null

  // Local filter states
  property string currentStatusFilter: "open" // "open", "active", "todo", "backlog", "done", "all"
  property string currentProjectFilter: ""   // "" means all projects
  property string searchQuery: ""

  readonly property var filteredTasks: {
    var all = (root.client && root.client.tasks) ? root.client.tasks : []
    var query = root.searchQuery.trim().toLowerCase()
    var statusF = root.currentStatusFilter
    var projF = root.currentProjectFilter

    var out = []
    for (var i = 0; i < all.length; i++) {
      var t = all[i]
      if (t.deleted) continue

      var st = t.status || ""
      var pr = t.project || ""

      // Project filter
      if (projF && pr !== projF) continue

      // Status filter
      if (statusF === "open") {
        if (st !== "inbox" && st !== "backlog" && st !== "todo" && st !== "active") continue
      } else if (statusF === "active") {
        if (st !== "active") continue
      } else if (statusF === "todo") {
        if (st !== "todo") continue
      } else if (statusF === "backlog") {
        if (st !== "backlog") continue
      } else if (statusF === "done") {
        if (st !== "done") continue
      }

      // Search query filter
      if (query) {
        var matchTitle = (t.title || "").toLowerCase().indexOf(query) !== -1
        var matchRef = (t.ref || "").toLowerCase().indexOf(query) !== -1
        var matchProj = (t.project || "").toLowerCase().indexOf(query) !== -1
        if (!matchTitle && !matchRef && !matchProj) continue
      }

      out.push(t)
    }
    return out
  }

  function launchDesktopWindow() {
    root.close()
    if (root.bar) {
      root.bar.run("omarchy-shell shell summon omaven \"{}\"")
    }
  }

  function launchTui() {
    if (root.client) {
      root.client.openTui(root.currentProjectFilter)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    contentWidth: Style.space(430)
    contentHeight: Style.space(560)

    content: Component {
      Item {
        id: card
        anchors.fill: parent

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.spacing.md
          spacing: Style.spacing.sm

          // --- Header ---
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.xs

            Text {
              text: "󰄲"
              font.family: Style.font.family
              font.pixelSize: Style.font.title * 1.1
              color: Commons.Color.accent
            }

            Text {
              text: "Omaven"
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              color: Commons.Color.foreground
            }

            // Sync indicator pill
            Rectangle {
              Layout.leftMargin: Style.spacing.xs
              implicitWidth: syncRow.implicitWidth + Style.space(10)
              implicitHeight: Style.space(20)
              radius: height / 2
              color: root.client && root.client.syncing ? "#1e3a5f" : "#1a2230"
              border.width: 1
              border.color: root.client && root.client.syncing ? "#3b82f6" : "#2a364a"

              Row {
                id: syncRow
                anchors.centerIn: parent
                spacing: Style.space(4)

                Text {
                  text: "󰑐"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption * 0.95
                  color: root.client && root.client.syncing ? "#60a5fa" : Commons.Color.muted
                  rotation: root.client && root.client.syncing ? syncAngle.angle : 0
                  NumberAnimation on rotation {
                    id: syncAngle
                    running: root.client && root.client.syncing
                    loops: Animation.Infinite
                    from: 0; to: 360; duration: 800
                  }
                }

                Text {
                  text: root.client && root.client.syncing ? "Syncing" : "Synced"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption * 0.85
                  color: root.client && root.client.syncing ? "#60a5fa" : Commons.Color.muted
                }
              }
            }

            Item { Layout.fillWidth: true }

            // Sync action button
            PanelActionButton {
              iconText: "󰑐"
              tooltipText: "Sync with server"
              onClicked: {
                if (root.client) root.client.triggerSync()
              }
            }

            // Launch desktop window button
            PanelActionButton {
              iconText: "↗"
              tooltipText: "Open as proper Desktop Window (can float/tile in Hyprland)"
              onClicked: root.launchDesktopWindow()
            }

            // Launch Terminal TUI button
            PanelActionButton {
              iconText: "󰆍"
              tooltipText: "Open Aven in Terminal TUI"
              onClicked: root.launchTui()
            }

            // Close button
            PanelActionButton {
              iconText: "󰅖"
              tooltipText: "Close popup"
              onClicked: root.close()
            }
          }

          // --- Quick Add & Search input ---
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.xs

            TextField {
              id: searchInput
              Layout.fillWidth: true
              placeholderText: "Filter or type new task title + Enter..."
              text: root.searchQuery
              onTextChanged: root.searchQuery = text

              Keys.onReturnPressed: {
                var val = searchInput.text.trim()
                if (!val) return
                if (root.client) {
                  root.client.addTask(val, root.currentProjectFilter, "none", "todo", function(res) {
                    if (res && res.ok) {
                      searchInput.text = ""
                      root.searchQuery = ""
                    }
                  })
                }
              }
            }

            PanelActionButton {
              iconText: "󰐕"
              tooltipText: "Add Task"
              enabled: searchInput.text.trim().length > 0
              onClicked: {
                var val = searchInput.text.trim()
                if (!val) return
                if (root.client) {
                  root.client.addTask(val, root.currentProjectFilter, "none", "todo", function(res) {
                    if (res && res.ok) {
                      searchInput.text = ""
                      root.searchQuery = ""
                    }
                  })
                }
              }
            }
          }

          // --- Status Filter Chips ---
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)

            Repeater {
              model: [
                { id: "open", label: "Open (" + (root.client ? root.client.counts.open : 0) + ")" },
                { id: "active", label: "Active (" + (root.client ? root.client.counts.active : 0) + ")" },
                { id: "todo", label: "Todo (" + (root.client ? root.client.counts.todo : 0) + ")" },
                { id: "backlog", label: "Backlog (" + (root.client ? root.client.counts.backlog : 0) + ")" },
                { id: "done", label: "Done (" + (root.client ? root.client.counts.done : 0) + ")" }
              ]

              delegate: Rectangle {
                required property var modelData
                readonly property bool isSelected: root.currentStatusFilter === modelData.id

                implicitWidth: chipText.implicitWidth + Style.space(12)
                implicitHeight: Style.space(22)
                radius: Style.cornerRadius
                color: isSelected ? Commons.Color.accent : (chipMouse.containsMouse ? "#263040" : "#1a2230")
                border.width: 1
                border.color: isSelected ? Commons.Color.accent : "#2d384b"

                Text {
                  id: chipText
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: parent.modelData.label
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption * 0.9
                  font.bold: parent.isSelected
                  color: parent.isSelected ? "white" : Commons.Color.foreground
                }

                MouseArea {
                  id: chipMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.currentStatusFilter = parent.modelData.id
                }
              }
            }
          }

          // --- Project Filter Chips (Scrollable row) ---
          Flickable {
            Layout.fillWidth: true
            implicitHeight: Style.space(24)
            contentWidth: projectRow.implicitWidth
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
              id: projectRow
              spacing: Style.space(4)

              // "All" Project pill
              Rectangle {
                readonly property bool isSelected: root.currentProjectFilter === ""
                implicitWidth: allProjText.implicitWidth + Style.space(10)
                implicitHeight: Style.space(20)
                radius: height / 2
                color: isSelected ? "#334155" : (pMouseAll.containsMouse ? "#1e293b" : "transparent")
                border.width: 1
                border.color: isSelected ? Commons.Color.accent : "#334155"

                Text {
                  id: allProjText
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: "All Projects"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption * 0.85
                  color: parent.isSelected ? Commons.Color.accent : Commons.Color.muted
                }

                MouseArea {
                  id: pMouseAll
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.currentProjectFilter = ""
                }
              }

              // Project pills
              Repeater {
                model: (root.client && root.client.projects) ? root.client.projects : []

                delegate: Rectangle {
                  required property var modelData
                  readonly property bool isSelected: root.currentProjectFilter === modelData.key

                  implicitWidth: projLabel.implicitWidth + Style.space(10)
                  implicitHeight: Style.space(20)
                  radius: height / 2
                  color: isSelected ? "#334155" : (pMouse.containsMouse ? "#1e293b" : "transparent")
                  border.width: 1
                  border.color: isSelected ? Commons.Color.accent : "#2d3748"

                  Text {
                    id: projLabel
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: (parent.modelData.name || parent.modelData.key) + " (" + (parent.modelData.count || 0) + ")"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption * 0.85
                    color: parent.isSelected ? Commons.Color.accent : Commons.Color.muted
                  }

                  MouseArea {
                    id: pMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentProjectFilter = parent.modelData.key
                  }
                }
              }
            }
          }

          // --- Task List ---
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
              id: listView
              anchors.fill: parent
              clip: true
              model: root.filteredTasks
              spacing: Style.space(4)
              boundsBehavior: Flickable.StopAtBounds

              ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
              }

              delegate: Rectangle {
                id: itemCard
                required property var modelData
                required property int index

                readonly property bool isDone: modelData.status === "done"
                readonly property bool isActive: modelData.status === "active"
                readonly property string priority: modelData.priority || "none"

                width: listView.width - (listView.ScrollBar.vertical.visible ? Style.space(8) : 0)
                implicitHeight: contentCol.implicitHeight + Style.space(12)
                radius: Style.cornerRadius
                color: itemMouse.containsMouse ? "#1e2638" : "#141b27"
                border.width: 1
                border.color: isActive ? Commons.Color.accent : (itemMouse.containsMouse ? "#2b3952" : "#1e283b")

                RowLayout {
                  id: contentCol
                  anchors.fill: parent
                  anchors.margins: Style.space(6)
                  spacing: Style.space(8)

                  // Status Checkbox / Action button
                  Rectangle {
                    implicitWidth: Style.space(24)
                    implicitHeight: Style.space(24)
                    radius: Style.space(4)
                    color: itemCard.isDone ? "#065f46" : (itemCard.isActive ? "#7c2d12" : "#1f2937")
                    border.width: 1
                    border.color: itemCard.isDone ? "#10b981" : (itemCard.isActive ? "#f97316" : "#4b5563")

                    Text {
                      anchors.centerIn: parent
                      text: itemCard.isDone ? "󰄲" : (itemCard.isActive ? "󰐊" : "󰄱")
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      color: itemCard.isDone ? "#34d399" : (itemCard.isActive ? "#fb923c" : "#9ca3af")
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (!root.client) return
                        var nextStatus = itemCard.isDone ? "todo" : "done"
                        root.client.updateStatus(itemCard.modelData.ref, nextStatus)
                      }
                    }
                  }

                  // Title, ref, tags
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(2)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(4)

                      // Project badge
                      Rectangle {
                        visible: !!itemCard.modelData.project
                        implicitWidth: projBadgeText.implicitWidth + Style.space(6)
                        implicitHeight: Style.space(16)
                        radius: Style.space(3)
                        color: "#1e293b"
                        border.width: 1
                        border.color: "#334155"

                        Text {
                          id: projBadgeText
                          anchors.centerIn: parent
                          textFormat: Text.PlainText
                          text: (itemCard.modelData.project || "").toUpperCase()
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption * 0.75
                          font.bold: true
                          color: "#94a3b8"
                        }
                      }

                      // Priority badge
                      Rectangle {
                        visible: itemCard.priority !== "none"
                        implicitWidth: prioText.implicitWidth + Style.space(6)
                        implicitHeight: Style.space(16)
                        radius: Style.space(3)
                        color: itemCard.priority === "urgent" ? "#450a0a" : (itemCard.priority === "high" ? "#431407" : "#1e293b")
                        border.width: 1
                        border.color: itemCard.priority === "urgent" ? "#ef4444" : (itemCard.priority === "high" ? "#f97316" : "#3b82f6")

                        Text {
                          id: prioText
                          anchors.centerIn: parent
                          textFormat: Text.PlainText
                          text: itemCard.priority.toUpperCase()
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption * 0.75
                          font.bold: true
                          color: itemCard.priority === "urgent" ? "#fca5a5" : (itemCard.priority === "high" ? "#fdba74" : "#93c5fd")
                        }
                      }

                      // Ref
                      Text {
                        textFormat: Text.PlainText
                        text: itemCard.modelData.ref || ""
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption * 0.8
                        color: Commons.Color.muted
                      }

                      Item { Layout.fillWidth: true }
                    }

                    // Title (safety compliant: PlainText)
                    Text {
                      Layout.fillWidth: true
                      textFormat: Text.PlainText
                      text: itemCard.modelData.title || ""
                      wrapMode: Text.Wrap
                      maximumLineCount: 2
                      elide: Text.ElideRight
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body * 0.95
                      color: itemCard.isDone ? Commons.Color.muted : Commons.Color.foreground
                      font.strikeout: itemCard.isDone
                    }
                  }

                  // Row action buttons (visible on hover)
                  Row {
                    visible: itemMouse.containsMouse
                    spacing: Style.space(2)

                    // Active / In-progress toggle
                    PanelActionButton {
                      visible: !itemCard.isDone
                      iconText: itemCard.isActive ? "󰄱" : "󰐊"
                      tooltipText: itemCard.isActive ? "Mark Todo" : "Mark Active"
                      onClicked: {
                        if (root.client) {
                          root.client.updateStatus(itemCard.modelData.ref, itemCard.isActive ? "todo" : "active")
                        }
                      }
                    }

                    // Delete task
                    PanelActionButton {
                      iconText: "󰩺"
                      tooltipText: "Delete Task"
                      hoverColor: "#ef4444"
                      onClicked: {
                        if (root.client) {
                          root.client.deleteTask(itemCard.modelData.ref)
                        }
                      }
                    }
                  }
                }

                MouseArea {
                  id: itemMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.RightButton
                  onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                      root.launchDesktopWindow()
                    }
                  }
                }
              }
            }

            // Empty state label
            Column {
              anchors.centerIn: parent
              visible: root.filteredTasks.length === 0
              spacing: Style.spacing.xs

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰄲"
                font.family: Style.font.family
                font.pixelSize: Style.font.title * 2
                color: Commons.Color.muted
                opacity: 0.4
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.searchQuery ? "No tasks matching filter" : "No tasks found"
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                color: Commons.Color.muted
              }
            }
          }

          // --- Footer ---
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.xs

            Text {
              textFormat: Text.PlainText
              text: (root.client ? root.client.counts.open : 0) + " open tasks · " + (root.client ? root.client.projects.length : 0) + " projects"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption * 0.85
              color: Commons.Color.muted
            }

            Item { Layout.fillWidth: true }

            Text {
              text: "↗ Pop out to window"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption * 0.85
              color: Commons.Color.accent

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launchDesktopWindow()
              }
            }
          }
        }
      }
    }
  }
}
