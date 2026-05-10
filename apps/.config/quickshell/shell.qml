//@ pragma UseQApplication
import Quickshell

Scope {
    NotificationPopup {
        id: notifications
    }

    Dimmer {
        id: dimmer
    }

    Bar {
        notifUnread: notifications.unread
        notifHistory: notifications.history
        notifMode: notifications.mode
        notifActivateFn: (entry) => notifications.activateHistoryEntry(entry)
        notifSetModeFn: (mode) => notifications.setMode(mode)
        onNotifCleared: notifications.markRead()
        onNotifHistoryCleared: notifications.clearHistory()
        dimAmount: dimmer.dimAmount
        onDimChanged: (val) => dimmer.dimAmount = val
    }
}
