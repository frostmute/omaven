pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string backendBin: String(Qt.resolvedUrl("bin/aven-backend")).replace(/^file:\/\//, "")

  property var tasks: []
  property var counts: ({
    "total": 0,
    "open": 0,
    "active": 0,
    "todo": 0,
    "backlog": 0,
    "done": 0,
    "canceled": 0,
    "urgent": 0,
    "high": 0
  })
  property var projects: []
  property var syncInfo: ({
    "state": "ready",
    "server": "",
    "devices": 0,
    "pending": false,
    "conflicts": 0
  })

  property bool loading: false
  property bool syncing: false
  property string lastError: ""

  signal refreshed()
  signal syncFinished(bool ok, string message)

  function refresh() {
    if (loading) return
    loading = true
    lastError = ""
    listProc.running = true
  }

  Process {
    id: listProc
    command: [root.backendBin, "list"]
    stdout: StdioCollector {
      id: listStdout
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode === 0 && listStdout.text) {
        try {
          var data = JSON.parse(listStdout.text)
          if (data && data.ok) {
            root.tasks = data.tasks || []
            root.counts = data.counts || root.counts
            root.projects = data.projects || []
            root.syncInfo = data.sync || root.syncInfo
            root.refreshed()
            return
          } else if (data && data.error) {
            root.lastError = data.error
          }
        } catch (e) {
          root.lastError = "Failed to parse tasks list: " + e
        }
      } else {
        root.lastError = "Failed to list tasks (exit code " + exitCode + ")"
      }
    }
  }

  // --- Task mutations ---
  property var _pendingCallbacks: ({})

  function updateStatus(ref, newStatus, cb) {
    var proc = actionProcComponent.createObject(root, {
      commandArgs: [root.backendBin, "edit", ref, "--status", newStatus],
      callback: cb
    })
    proc.start()
  }

  function updatePriority(ref, newPriority, cb) {
    var proc = actionProcComponent.createObject(root, {
      commandArgs: [root.backendBin, "edit", ref, "--priority", newPriority],
      callback: cb
    })
    proc.start()
  }

  function addTask(title, project, priority, status, cb) {
    var args = [root.backendBin, "add"]
    if (project) args.push("--project", project)
    if (priority && priority !== "none") args.push("--priority", priority)
    if (status) args.push("--status", status)

    var proc = actionProcComponent.createObject(root, {
      commandArgs: args,
      input: title,
      callback: cb
    })
    proc.start()
  }

  function deleteTask(ref, cb) {
    var proc = actionProcComponent.createObject(root, {
      commandArgs: [root.backendBin, "delete", ref],
      callback: cb
    })
    proc.start()
  }

  function addNote(ref, text, cb) {
    var proc = actionProcComponent.createObject(root, {
      commandArgs: [root.backendBin, "note", ref],
      input: text,
      callback: cb
    })
    proc.start()
  }

  function triggerSync(cb) {
    if (root.syncing) return
    root.syncing = true
    var proc = syncProcComponent.createObject(root, {
      callback: cb
    })
    proc.start()
  }

  function openTui(project) {
    var args = [root.backendBin, "tui"]
    if (project) args.push(project)
    var proc = actionProcComponent.createObject(root, {
      commandArgs: args
    })
    proc.start()
  }

  Component {
    id: actionProcComponent
    Process {
      id: ap
      property var commandArgs: []
      property var callback: null
      property var input: null

      command: commandArgs
      stdinEnabled: input !== null
      onStarted: {
        if (input !== null) ap.write(JSON.stringify(input) + "\n")
      }
      stdout: StdioCollector {
        id: apStdout
        waitForEnd: true
      }

      function start() {
        ap.running = true
      }

      onExited: function(exitCode) {
        var res = { ok: exitCode === 0, text: apStdout.text }
        try {
          if (apStdout.text) res = JSON.parse(apStdout.text)
        } catch (e) {}

        if (typeof ap.callback === "function") {
          ap.callback(res)
        }
        // Auto refresh state on success
        if (res.ok) {
          root.refresh()
        }
        ap.destroy()
      }
    }
  }

  Component {
    id: syncProcComponent
    Process {
      id: sp
      property var callback: null

      command: [root.backendBin, "sync"]
      stdout: StdioCollector {
        id: spStdout
        waitForEnd: true
      }

      function start() {
        sp.running = true
      }

      onExited: function(exitCode) {
        root.syncing = false
        var ok = exitCode === 0
        var msg = spStdout.text
        try {
          var parsed = JSON.parse(spStdout.text)
          if (parsed) {
            ok = parsed.ok === true
            msg = parsed.message || parsed.error || msg
            if (parsed.sync) root.syncInfo = parsed.sync
          }
        } catch (e) {}

        root.syncFinished(ok, msg)
        if (typeof sp.callback === "function") {
          sp.callback(ok, msg)
        }
        root.refresh()
        sp.destroy()
      }
    }
  }

  // Periodic refresh
  Timer {
    interval: 60000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
