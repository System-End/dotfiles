import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    property var history: []
    property int unread: 0
    property string mode: "normal"
    property string pendingLaunchId: ""

    function runDesktopEntry(desktopEntry) {
        var id = String(desktopEntry || "")
        if (id.endsWith(".desktop")) id = id.slice(0, -8)
        if (id === "") return
        launchProc.command = ["gtk-launch", id]
        launchProc.running = true
    }

    function normalized(str) {
        return String(str || "").toLowerCase().trim()
    }

    function dedupe(list) {
        var out = []
        var seen = {}
        for (var i = 0; i < list.length; i++) {
            var value = normalized(list[i])
            if (value === "" || seen[value]) continue
            seen[value] = true
            out.push(value)
        }
        return out
    }

    function fallbackDesktopId(appName) {
        var key = normalized(appName)
        if (key === "discord") return "discord"
        if (key === "vesktop") return "vesktop"
        if (key === "signal") return "signal-desktop"
        if (key === "slack") return "slack"
        if (key === "spotify") return "spotify"
        if (key === "thunderbird") return "org.mozilla.Thunderbird"
        if (key === "zen browser") return "zen"
        if (key === "zen") return "zen"
        if (key === "obsidian") return "obsidian"
        if (key === "helium") return "helium"
        return ""
    }

    function appIdCandidates(appName, desktopEntry) {
        var key = normalized(appName)
        var ids = []
        var desktopId = normalized(desktopEntry || "")

        if (desktopId.endsWith(".desktop")) desktopId = desktopId.slice(0, -8)
        if (desktopId !== "") {
            ids.push(desktopId)
            ids.push(desktopId.replace(/-/g, " "))
            ids.push(desktopId.replace(/\./g, " "))
        }

        if (key !== "") {
            ids.push(key)
            ids.push(key.replace(/\s+/g, "-"))
            ids.push(key.replace(/\s+/g, ""))
        }

        if (key === "discord" || key === "vesktop") ids = ids.concat(["discord", "vesktop", "com.discordapp.discord"])
        if (key === "signal") ids = ids.concat(["signal", "signal-desktop"])
        if (key === "slack") ids = ids.concat(["slack", "app.slack"])
        if (key === "spotify") ids = ids.concat(["spotify"])
        if (key === "thunderbird") ids = ids.concat(["thunderbird", "org.mozilla.thunderbird"])
        if (key === "zen browser" || key === "zen") ids = ids.concat(["zen", "zen-browser"])
        if (key === "obsidian") ids = ids.concat(["obsidian", "md.obsidian"])
        if (key === "helium") ids = ids.concat(["helium", "helium-browser"])

        return dedupe(ids)
    }

    function focusKnownWindow(appName, desktopEntry, allowLaunchFallback) {
        var ids = appIdCandidates(appName, desktopEntry)
        var title = normalized(appName)
        if (ids.length === 0 && title === "") {
            if (allowLaunchFallback && desktopEntry) runDesktopEntry(desktopEntry)
            return false
        }

        pendingLaunchId = allowLaunchFallback ? String(desktopEntry || fallbackDesktopId(appName) || "") : ""
        focusProc.command = [
            "python3",
            "-c",
            "import json,subprocess,sys\npats={s.lower() for s in json.loads(sys.argv[1]) if s}\ntitle=(sys.argv[2] or '').strip().lower()\nwins=json.loads(subprocess.check_output(['niri','msg','-j','windows']))\nfound=None\nfor w in wins:\n aid=str(w.get('app_id') or '').lower()\n ttl=str(w.get('title') or '').lower()\n if aid in pats or any(p in aid for p in pats) or (title and title in ttl):\n  found=str(w.get('id'))\n  break\nsys.exit(subprocess.call(['niri','msg','action','focus-window','--id',found]) if found else 1)",
            JSON.stringify(ids),
            title,
        ]
        focusProc.running = true
        return true
    }

    function activateNotification(notif) {
        if (!notif) return

        var acts = notif.actions || []
        if (acts.length === 1) {
            try {
                acts[0].invoke()
                focusKnownWindow(notif.appName, notif.desktopEntry, false)
                return
            } catch (e) {}
        }

        for (var i = 0; i < acts.length; i++) {
            var a = acts[i]
            if (!a) continue
            if (!a.identifier || String(a.identifier).toLowerCase() === "default") {
                var invoked = false
                try {
                    a.invoke()
                    invoked = true
                } catch (e) {}

                if (invoked) {
                    focusKnownWindow(notif.appName, notif.desktopEntry, false)
                    return
                }
            }
        }

        if (focusKnownWindow(notif.appName, notif.desktopEntry, true)) {
            return
        }

        var mapped = fallbackDesktopId(notif.appName)
        if (mapped !== "") runDesktopEntry(mapped)
    }

    function activateHistoryEntry(entry) {
        if (!entry) return

        if (entry.notif) {
            try {
                if (entry.notif.tracked) {
                    activateNotification(entry.notif)
                    return
                }
            } catch (e) {}
        }

        if (entry.desktopEntry && entry.desktopEntry !== "") {
            if (focusKnownWindow(entry.app, entry.desktopEntry, true)) return
            runDesktopEntry(entry.desktopEntry)
            return
        }

        var mapped = fallbackDesktopId(entry.app)
        if (mapped !== "") runDesktopEntry(mapped)
    }

    function historyEntryById(id) {
        for (var i = history.length - 1; i >= 0; i--) {
            if (history[i].id === id) return history[i]
        }
        return null
    }

    function markRead() {
        unread = 0
    }

    function clearHistory() {
        history = []
        unread = 0
    }

    function setMode(nextMode) {
        mode = nextMode === "dnd" ? "dnd" : "normal"
        saveModeProc.command = [
            "bash",
            "-lc",
            "mkdir -p ~/.local/state/quickshell && printf '%s\n' " + mode + " > ~/.local/state/quickshell/notification-mode",
        ]
        saveModeProc.running = true
    }

    Process { id: launchProc }
    Process { id: saveModeProc }
    Process {
        id: loadModeProc
        command: ["bash", "-lc", "cat ~/.local/state/quickshell/notification-mode 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: root.mode = this.text.trim() === "dnd" ? "dnd" : "normal"
        }
    }
    Process {
        id: focusProc
        onExited: (code) => {
            if (code !== 0 && pendingLaunchId !== "") runDesktopEntry(pendingLaunchId)
            pendingLaunchId = ""
        }
    }

    Component.onCompleted: loadModeProc.running = true

    NotificationServer {
        id: server
        actionsSupported: true

        onNotification: (notif) => {
            notif.tracked = true

            var private_ = normalized(notif.appName).indexOf("signal") !== -1
            var entry = {
                id: notif.id,
                app: notif.appName || "notification",
                summary: notif.summary || "",
                body: private_ ? "" : (notif.body || ""),
                desktopEntry: notif.desktopEntry || "",
                notif: notif,
                time: Date.now()
            }

            var arr = root.history.slice()
            arr.push(entry)
            if (arr.length > 100) arr.shift()
            root.history = arr
            root.unread++

            if (root.mode !== "dnd") {
                toastModel.append({
                    id: entry.id,
                    app: entry.app,
                    summary: entry.summary,
                    body: entry.body,
                    desktopEntry: entry.desktopEntry,
                })
            }

            var ms = notif.expireTimeout > 0 ? notif.expireTimeout : 8000
            expireTimer.createObject(root, { notifId: notif.id, delay: ms })
        }
    }

    Component {
        id: expireTimer
        Timer {
            property int notifId
            property int delay: 8000
            interval: delay
            running: true
            repeat: false
            onTriggered: {
                for (var i = 0; i < toastModel.count; i++) {
                    if (toastModel.get(i).id === notifId) {
                        toastModel.remove(i)
                        break
                    }
                }
                destroy()
            }
        }
    }

    ListModel { id: toastModel }

    PanelWindow {
        screen: Quickshell.screens[0]
        color: "transparent"
        anchors { top: true; right: true }
        implicitWidth: 360
        implicitHeight: toastCol.implicitHeight + 16
        visible: toastModel.count > 0
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Column {
            id: toastCol
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            width: 344
            spacing: 6

            Repeater {
                model: toastModel
                delegate: Rectangle {
                    required property var model
                    width: 344
                    height: toastContent.implicitHeight + 20
                    color: "#0f1120"
                    radius: 14
                    border.color: Qt.rgba(0.306, 0.788, 0.690, 0.15)
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                root.activateHistoryEntry(root.historyEntryById(model.id) || model)
                            }
                            for (var i = 0; i < toastModel.count; i++) {
                                if (toastModel.get(i).id === model.id) {
                                    toastModel.remove(i)
                                    break
                                }
                            }
                        }
                    }

                    Column {
                        id: toastContent
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        anchors.margins: 12
                        spacing: 4

                        Text {
                            text: model.app
                            color: "#c792ea"
                            font.family: "Maple Mono NF"
                            font.pixelSize: 11
                            font.bold: true
                        }
                        Text {
                            text: model.summary
                            color: "#cdd6f4"
                            font.family: "Maple Mono NF"
                            font.pixelSize: 13
                            font.bold: true
                            width: parent.width
                            elide: Text.ElideRight
                            visible: model.summary !== ""
                        }
                        Text {
                            text: model.body
                            color: "#7f849c"
                            font.family: "Maple Mono NF"
                            font.pixelSize: 12
                            width: parent.width
                            wrapMode: Text.WordWrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            visible: model.body !== ""
                        }
                    }
                }
            }
        }
    }
}
