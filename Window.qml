pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool closingFromHost: false

  function open(payloadJson) {
    closingFromHost = false
    win.visible = true
    client.refresh()
  }

  function close() {
    closingFromHost = true
    win.visible = false
    closingFromHost = false
  }

  AvenClient {
    id: client
  }

  // Selected filters and task
  property string currentView: "open" // "open", "active", "todo", "backlog", "done"
  property string currentProject: ""  // "" for all
  property string currentPriority: "" // "" for all
  property string searchQuery: ""
  property var selectedTask: null
  property bool showNewTaskModal: false

  // Filtered task list
  readonly property var filteredTasks: {
    var all = client.tasks || []
    var query = root.searchQuery.trim().toLowerCase()
    var view = root.currentView
    var proj = root.currentProject
    var prio = root.currentPriority

    var out = []
    for (var i = 0; i < all.length; i++) {
      var t = all[i]
      if (t.deleted) continue

      var st = t.status || ""
      var pr = t.project || ""
      var prVal = t.priority || "none"

      // Project filter
      if (proj && pr !== proj) continue

      // Priority filter
      if (prio && prVal !== prio) continue

      // View filter
      if (view === "open") {
        if (st !== "inbox" && st !== "backlog" && st !== "todo" && st !== "active") continue
      } else if (view === "active") {
        if (st !== "active") continue
      } else if (view === "todo") {
        if (st !== "todo") continue
      } else if (view === "backlog") {
        if (st !== "backlog") continue
      } else if (view === "done") {
        if (st !== "done") continue
      }

      // Search filter
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

  FloatingWindow {
    id: win
    title: "Omaven — Aven Task Manager"
    appId: "omaven"
    color: Commons.Color.background
    implicitWidth: 1040
    implicitHeight: 700
    minimumSize: Qt.size(760, 500)

    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function") {
        root.shell.hide("omaven")
      }
    }

    FocusScope {
      id: focusScope
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (root.showNewTaskModal) {
            root.showNewTaskModal = false
            event.accepted = true
          } else {
            win.visible = false
            event.accepted = true
          }
        } else if (event.key === Qt.Key_A && !taskSearchField.activeFocus && !newTitleField.activeFocus) {
          root.showNewTaskModal = true
          event.accepted = true
        } else if (event.key === Qt.Key_S && !taskSearchField.activeFocus && !newTitleField.activeFocus) {
          client.triggerSync()
          event.accepted = true
        } else if (event.key === Qt.Key_Slash && !taskSearchField.activeFocus && !newTitleField.activeFocus) {
          taskSearchField.forceActiveFocus()
          event.accepted = true
        }
      }

      RowLayout {
        anchors.fill: parent
        spacing: 0

        // ==========================================
        // LEFT SIDEBAR
        // ==========================================
        Rectangle {
          Layout.preferredWidth: Style.space(240)
          Layout.fillHeight: true
          color: "#0f1520"
          border.width: 1
          border.color: "#1e283b"

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.spacing.md
            spacing: Style.spacing.sm

            // App Header
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.spacing.xs

              Text {
                text: "󰄲"
                font.family: Style.font.family
                font.pixelSize: Style.font.title * 1.3
                color: Commons.Color.accent
              }

              Column {
                Text {
                  text: "OMAVEN"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                  color: Commons.Color.foreground
                }
                Text {
                  text: "Aven Tasks for Omarchy"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption * 0.85
                  color: Commons.Color.muted
                }
              }

              Item { Layout.fillWidth: true }
            }

            // Quick separator
            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: "#1e283b"
            }

            // Views section header
            Text {
              text: "VIEWS"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption * 0.8
              font.bold: true
              color: Commons.Color.muted
              Layout.topMargin: Style.space(4)
            }

            // Navigation items
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(2)

              Repeater {
                model: [
                  { id: "open", icon: "󰄵", label: "All Open", count: client.counts.open },
                  { id: "active", icon: "󰐊", label: "Active", count: client.counts.active },
                  { id: "todo", icon: "󰄱", label: "Todo", count: client.counts.todo },
                  { id: "backlog", icon: "󰇘", label: "Backlog", count: client.counts.backlog },
                  { id: "done", icon: "󰄲", label: "Completed", count: client.counts.done }
                ]

                delegate: Rectangle {
                  required property var modelData
                  readonly property bool isSelected: root.currentView === modelData.id && root.currentProject === ""

                  Layout.fillWidth: true
                  implicitHeight: Style.space(32)
                  radius: Style.cornerRadius
                  color: isSelected ? Commons.Color.accent : (navMouse.containsMouse ? "#1e293b" : "transparent")

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    spacing: Style.space(8)

                    Text {
                      text: parent.parent.modelData.icon
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      color: parent.parent.isSelected ? "white" : Commons.Color.muted
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: parent.parent.modelData.label
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body * 0.95
                      font.bold: parent.parent.isSelected
                      color: parent.parent.isSelected ? "white" : Commons.Color.foreground
                      Layout.fillWidth: true
                    }

                    Text {
                      text: String(parent.parent.modelData.count || 0)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption * 0.9
                      font.bold: true
                      color: parent.parent.isSelected ? "white" : Commons.Color.muted
                    }
                  }

                  MouseArea {
                    id: navMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.currentView = parent.modelData.id
                      root.currentProject = ""
                    }
                  }
                }
              }
            }

            // Projects section header
            Text {
              text: "PROJECTS"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption * 0.8
              font.bold: true
              color: Commons.Color.muted
              Layout.topMargin: Style.space(12)
            }

            // Project items
            ListView {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              model: client.projects || []
              spacing: Style.space(2)

              delegate: Rectangle {
                required property var modelData
                readonly property bool isSelected: root.currentProject === modelData.key

                width: parent.width
                implicitHeight: Style.space(30)
                radius: Style.cornerRadius
                color: isSelected ? "#334155" : (pNavMouse.containsMouse ? "#1a2233" : "transparent")
                border.width: isSelected ? 1 : 0
                border.color: Commons.Color.accent

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: Style.space(8)

                  Text {
                    text: "󰉓"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body * 0.9
                    color: parent.parent.isSelected ? Commons.Color.accent : Commons.Color.muted
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: parent.parent.modelData.name || parent.parent.modelData.key
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body * 0.9
                    font.bold: parent.parent.isSelected
                    color: parent.parent.isSelected ? "white" : Commons.Color.foreground
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  Text {
                    text: String(parent.parent.modelData.count || 0)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption * 0.85
                    color: Commons.Color.muted
                  }
                }

                MouseArea {
                  id: pNavMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.currentProject = parent.modelData.key
                  }
                }
              }
            }

            // Bottom Sync Card
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: syncBoxCol.implicitHeight + Style.space(16)
              color: "#161f2e"
              radius: Style.cornerRadius
              border.width: 1
              border.color: "#253347"

              ColumnLayout {
                id: syncBoxCol
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(6)

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(4)

                  Text {
                    text: "󰑐"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body * 0.9
                    color: client.syncing ? "#60a5fa" : "#10b981"
                    rotation: client.syncing ? winSyncAngle.angle : 0
                    NumberAnimation on rotation {
                      id: winSyncAngle
                      running: client.syncing
                      loops: Animation.Infinite
                      from: 0; to: 360; duration: 800
                    }
                  }

                  Text {
                    text: client.syncing ? "Syncing changes..." : (client.syncInfo.server ? "Server connected" : "Local only")
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption * 0.85
                    color: Commons.Color.foreground
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(4)

                  Button {
                    Layout.fillWidth: true
                    text: "󰑐 Sync"
                    onClicked: client.triggerSync()
                  }

                  Button {
                    Layout.fillWidth: true
                    text: "󰆍 TUI"
                    onClicked: client.openTui(root.currentProject)
                  }
                }
              }
            }
          }
        }

        // ==========================================
        // MAIN CONTENT AREA
        // ==========================================
        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 0

          // Top Action Toolbar
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: Style.space(56)
            color: "#111827"
            border.width: 1
            border.color: "#1f2937"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.spacing.md
              anchors.rightMargin: Style.spacing.md
              spacing: Style.spacing.sm

              // Current View Heading
              Column {
                Text {
                  text: root.currentProject ? (root.currentProject.toUpperCase() + " TASKS") : (root.currentView.toUpperCase() + " TASKS")
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                  color: Commons.Color.foreground
                }
                Text {
                  text: root.filteredTasks.length + " tasks listed"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption * 0.85
                  color: Commons.Color.muted
                }
              }

              Item { Layout.fillWidth: true }

              // Search Field
              TextField {
                id: taskSearchField
                Layout.preferredWidth: Style.space(220)
                placeholderText: "Search tasks (/)..."
                text: root.searchQuery
                onTextChanged: root.searchQuery = text
              }

              // Priority Filter Dropdown
              ComboBox {
                id: prioFilterCombo
                model: [
                  { label: "All Priorities", value: "" },
                  { label: "Urgent", value: "urgent" },
                  { label: "High", value: "high" },
                  { label: "Medium", value: "medium" },
                  { label: "Low", value: "low" },
                  { label: "None", value: "none" }
                ]
                textRole: "label"
                onActivated: function(index) {
                  root.currentPriority = model[index].value
                }
              }

              // "+ New Task" Button
              Button {
                text: "󰐕 New Task"
                accent: Commons.Color.accent
                onClicked: root.showNewTaskModal = true
              }

              // Window close button
              PanelActionButton {
                iconText: "󰅖"
                tooltipText: "Close Window"
                onClicked: win.visible = false
              }
            }
          }

          // Main split: Task list (left) & Detail inspector (right)
          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Tasks List Table
            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              color: "transparent"

              ListView {
                id: mainListView
                anchors.fill: parent
                anchors.margins: Style.spacing.sm
                clip: true
                spacing: Style.space(4)
                model: root.filteredTasks
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                  id: mainRowCard
                  required property var modelData
                  required property int index

                  readonly property bool isSelected: root.selectedTask && root.selectedTask.ref === modelData.ref
                  readonly property bool isDone: modelData.status === "done"
                  readonly property bool isActive: modelData.status === "active"
                  readonly property string priority: modelData.priority || "none"

                  width: mainListView.width - (mainListView.ScrollBar.vertical.visible ? Style.space(10) : 0)
                  implicitHeight: Style.space(52)
                  radius: Style.cornerRadius
                  color: isSelected ? "#1e2d44" : (rowHoverMouse.containsMouse ? "#182233" : "#121926")
                  border.width: 1
                  border.color: isSelected ? Commons.Color.accent : (rowHoverMouse.containsMouse ? "#27354d" : "#1a2333")

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    spacing: Style.space(10)

                    // Status Checkbox
                    Rectangle {
                      implicitWidth: Style.space(24)
                      implicitHeight: Style.space(24)
                      radius: Style.space(4)
                      color: mainRowCard.isDone ? "#065f46" : (mainRowCard.isActive ? "#7c2d12" : "#1f2937")
                      border.width: 1
                      border.color: mainRowCard.isDone ? "#10b981" : (mainRowCard.isActive ? "#f97316" : "#4b5563")

                      Text {
                        anchors.centerIn: parent
                        text: mainRowCard.isDone ? "󰄲" : (mainRowCard.isActive ? "󰐊" : "󰄱")
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        color: mainRowCard.isDone ? "#34d399" : (mainRowCard.isActive ? "#fb923c" : "#9ca3af")
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          var nextStatus = mainRowCard.isDone ? "todo" : "done"
                          client.updateStatus(mainRowCard.modelData.ref, nextStatus)
                        }
                      }
                    }

                    // Project badge
                    Rectangle {
                      implicitWidth: rProjText.implicitWidth + Style.space(8)
                      implicitHeight: Style.space(20)
                      radius: Style.space(4)
                      color: "#1e293b"
                      border.width: 1
                      border.color: "#334155"

                      Text {
                        id: rProjText
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: (mainRowCard.modelData.project || "").toUpperCase()
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption * 0.8
                        font.bold: true
                        color: "#94a3b8"
                      }
                    }

                    // Ref
                    Text {
                      textFormat: Text.PlainText
                      text: mainRowCard.modelData.ref || ""
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body * 0.9
                      font.bold: true
                      color: Commons.Color.accent
                    }

                    // Title
                    Text {
                      Layout.fillWidth: true
                      textFormat: Text.PlainText
                      text: mainRowCard.modelData.title || ""
                      elide: Text.ElideRight
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      color: mainRowCard.isDone ? Commons.Color.muted : Commons.Color.foreground
                      font.strikeout: mainRowCard.isDone
                    }

                    // Priority pill
                    Rectangle {
                      visible: mainRowCard.priority !== "none"
                      implicitWidth: rPrioText.implicitWidth + Style.space(8)
                      implicitHeight: Style.space(20)
                      radius: Style.space(4)
                      color: mainRowCard.priority === "urgent" ? "#450a0a" : (mainRowCard.priority === "high" ? "#431407" : "#1e293b")
                      border.width: 1
                      border.color: mainRowCard.priority === "urgent" ? "#ef4444" : (mainRowCard.priority === "high" ? "#f97316" : "#3b82f6")

                      Text {
                        id: rPrioText
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: mainRowCard.priority.toUpperCase()
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption * 0.75
                        font.bold: true
                        color: mainRowCard.priority === "urgent" ? "#fca5a5" : (mainRowCard.priority === "high" ? "#fdba74" : "#93c5fd")
                      }
                    }

                    // Action buttons
                    Row {
                      visible: rowHoverMouse.containsMouse || mainRowCard.isSelected
                      spacing: Style.space(2)

                      PanelActionButton {
                        iconText: "󰐊"
                        tooltipText: "Set Active"
                        visible: !mainRowCard.isActive && !mainRowCard.isDone
                        onClicked: client.updateStatus(mainRowCard.modelData.ref, "active")
                      }

                      PanelActionButton {
                        iconText: "󰩺"
                        tooltipText: "Delete Task"
                        hoverColor: "#ef4444"
                        onClicked: client.deleteTask(mainRowCard.modelData.ref)
                      }
                    }
                  }

                  MouseArea {
                    id: rowHoverMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.selectedTask = mainRowCard.modelData
                    }
                  }
                }
              }

              // Empty placeholder
              Column {
                anchors.centerIn: parent
                visible: root.filteredTasks.length === 0
                spacing: Style.spacing.xs

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "󰄲"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title * 2.5
                  color: Commons.Color.muted
                  opacity: 0.3
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "No tasks found"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  color: Commons.Color.muted
                }
              }
            }

            // Divider line
            Rectangle {
              Layout.fillHeight: true
              width: 1
              color: "#1e293b"
              visible: !!root.selectedTask
            }

            // Task Details Inspector (Right pane)
            Rectangle {
              Layout.preferredWidth: Style.space(340)
              Layout.fillHeight: true
              color: "#101622"
              visible: !!root.selectedTask

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.spacing.md
                spacing: Style.spacing.sm

                // Detail Header
                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(6)

                  Text {
                    textFormat: Text.PlainText
                    text: root.selectedTask ? root.selectedTask.ref : ""
                    font.family: Style.font.family
                    font.pixelSize: Style.font.title
                    font.bold: true
                    color: Commons.Color.accent
                  }

                  Rectangle {
                    visible: root.selectedTask && !!root.selectedTask.project
                    implicitWidth: dProjText.implicitWidth + Style.space(8)
                    implicitHeight: Style.space(20)
                    radius: Style.space(4)
                    color: "#1e293b"

                    Text {
                      id: dProjText
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: (root.selectedTask ? root.selectedTask.project : "").toUpperCase()
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption * 0.8
                      color: "#94a3b8"
                    }
                  }

                  Item { Layout.fillWidth: true }

                  PanelActionButton {
                    iconText: "󰅖"
                    tooltipText: "Close details pane"
                    onClicked: root.selectedTask = null
                  }
                }

                // Title Display / Edit
                Text {
                  text: "TITLE"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption * 0.8
                  font.bold: true
                  color: Commons.Color.muted
                  Layout.topMargin: Style.space(6)
                }

                TextField {
                  id: editTitleField
                  Layout.fillWidth: true
                  text: root.selectedTask ? root.selectedTask.title : ""
                  onAccepted: {
                    if (root.selectedTask && text.trim() && text.trim() !== root.selectedTask.title) {
                      client.addTask(text.trim(), root.selectedTask.project)
                    }
                  }
                }

                // Status row
                Text {
                  text: "STATUS"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption * 0.8
                  font.bold: true
                  color: Commons.Color.muted
                  Layout.topMargin: Style.space(6)
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(4)

                  Repeater {
                    model: ["todo", "active", "done", "backlog"]

                    delegate: Button {
                      required property string modelData
                      Layout.fillWidth: true
                      text: modelData.toUpperCase()
                      accent: root.selectedTask && root.selectedTask.status === modelData ? Commons.Color.accent : Commons.Color.muted
                      onClicked: {
                        if (root.selectedTask) {
                          client.updateStatus(root.selectedTask.ref, modelData)
                        }
                      }
                    }
                  }
                }

                // Priority row
                Text {
                  text: "PRIORITY"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption * 0.8
                  font.bold: true
                  color: Commons.Color.muted
                  Layout.topMargin: Style.space(6)
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(4)

                  Repeater {
                    model: ["none", "low", "medium", "high", "urgent"]

                    delegate: Button {
                      required property string modelData
                      Layout.fillWidth: true
                      text: modelData.toUpperCase()
                      onClicked: {
                        if (root.selectedTask) {
                          client.updatePriority(root.selectedTask.ref, modelData)
                        }
                      }
                    }
                  }
                }

                // Add Note section
                Text {
                  text: "APPEND NOTE"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption * 0.8
                  font.bold: true
                  color: Commons.Color.muted
                  Layout.topMargin: Style.space(8)
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(4)

                  TextField {
                    id: noteInput
                    Layout.fillWidth: true
                    placeholderText: "Type note and press Enter..."
                    Keys.onReturnPressed: {
                      var n = noteInput.text.trim()
                      if (n && root.selectedTask) {
                        client.addNote(root.selectedTask.ref, n, function(res) {
                          noteInput.text = ""
                        })
                      }
                    }
                  }

                  Button {
                    text: "Add"
                    onClicked: {
                      var n = noteInput.text.trim()
                      if (n && root.selectedTask) {
                        client.addNote(root.selectedTask.ref, n, function(res) {
                          noteInput.text = ""
                        })
                      }
                    }
                  }
                }

                Item { Layout.fillHeight: true }

                // Delete button
                Button {
                  Layout.fillWidth: true
                  text: "󰩺 Delete Task"
                  accent: "#ef4444"
                  onClicked: {
                    if (root.selectedTask) {
                      client.deleteTask(root.selectedTask.ref)
                      root.selectedTask = null
                    }
                  }
                }
              }
            }
          }
        }
      }

      // ==========================================
      // NEW TASK MODAL OVERLAY
      // ==========================================
      Rectangle {
        id: newTaskModal
        anchors.fill: parent
        visible: root.showNewTaskModal
        color: "#b0000000"
        z: 99

        MouseArea {
          anchors.fill: parent
          onClicked: root.showNewTaskModal = false
        }

        Rectangle {
          width: Style.space(460)
          implicitHeight: modalCol.implicitHeight + Style.space(32)
          anchors.centerIn: parent
          radius: Style.cornerRadius
          color: "#182234"
          border.width: 1
          border.color: Commons.Color.accent

          MouseArea {
            anchors.fill: parent
            // prevent closing when clicking inside modal
          }

          ColumnLayout {
            id: modalCol
            anchors.fill: parent
            anchors.margins: Style.spacing.md
            spacing: Style.spacing.sm

            RowLayout {
              Layout.fillWidth: true
              Text {
                text: "Create New Aven Task"
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                color: Commons.Color.foreground
              }
              Item { Layout.fillWidth: true }
              PanelActionButton {
                iconText: "󰅖"
                onClicked: root.showNewTaskModal = false
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: "#2b3952"
            }

            Text {
              text: "Task Title"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Commons.Color.muted
            }

            TextField {
              id: newTitleField
              Layout.fillWidth: true
              placeholderText: "What needs to be done?"
              focus: root.showNewTaskModal
            }

            Text {
              text: "Project"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Commons.Color.muted
            }

            ComboBox {
              id: newProjectCombo
              Layout.fillWidth: true
              model: ["system", "habitex", "nexora", "underneon", "default"]
            }

            Text {
              text: "Priority"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Commons.Color.muted
            }

            ComboBox {
              id: newPriorityCombo
              Layout.fillWidth: true
              model: ["none", "low", "medium", "high", "urgent"]
            }

            Item { Layout.preferredHeight: Style.space(8) }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.spacing.sm

              Button {
                Layout.fillWidth: true
                text: "Cancel"
                onClicked: root.showNewTaskModal = false
              }

              Button {
                Layout.fillWidth: true
                text: "Create Task"
                accent: Commons.Color.accent
                enabled: newTitleField.text.trim().length > 0
                onClicked: {
                  var title = newTitleField.text.trim()
                  var proj = newProjectCombo.currentText
                  var prio = newPriorityCombo.currentText
                  if (title) {
                    client.addTask(title, proj, prio, "todo", function(res) {
                      newTitleField.text = ""
                      root.showNewTaskModal = false
                    })
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
