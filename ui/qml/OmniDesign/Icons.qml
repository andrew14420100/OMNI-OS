pragma Singleton
import QtQuick

// Icone originali OMNI: tracciati SVG su griglia 24×24, disegnati per questo progetto.
QtObject {
    readonly property var paths: ({
        "grid":    "M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z",
        "bell":    "M6 16V11a6 6 0 0 1 12 0v5l2 2H4zM10 20a2 2 0 0 0 4 0",
        "sliders": "M4 7h10M18 7h2M4 17h2M10 17h10M16 4v6M8 14v6",
        "wifi":    "M2.5 9a14 14 0 0 1 19 0M5.5 12.5a9.5 9.5 0 0 1 13 0M8.5 16a5 5 0 0 1 7 0M12 19.5h.01",
        "bluetooth": "M7 7l10 10-5 4V3l5 4L7 17",
        "moon":    "M20 14.5A8.5 8.5 0 1 1 9.5 4a7 7 0 0 0 10.5 10.5z",
        "sun":     "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4",
        "volume":  "M4 9h4l5-4v14l-5-4H4zM16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12",
        "search":  "M10.5 4a6.5 6.5 0 1 0 0 13 6.5 6.5 0 0 0 0-13zM15.5 15.5L20 20",
        "close":   "M6 6l12 12M18 6L6 18",
        "power":   "M12 3v8M7 6.3a7 7 0 1 0 10 0",
        "moon-off": "M3 3l18 18M20 14.5A8.5 8.5 0 0 1 9 19.6M6.2 6.2A8.5 8.5 0 0 0 9.5 4",
        "motion":  "M4 12h4l2-5 4 10 2-5h4",
        "sparkle": "M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z",
        "apps":    "M5 5h4v4H5zM10 5h4v4h-4zM15 5h4v4h-4zM5 10h4v4H5zM10 10h4v4h-4zM15 10h4v4h-4z"
    })
    function path(name) { return paths[name] !== undefined ? paths[name] : paths["sparkle"] }
}
