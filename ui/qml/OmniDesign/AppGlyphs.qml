pragma Singleton
import QtQuick

// Sistema di icone applicative OMNI (originale, disegnato per questo progetto).
// Ogni icona: fondo "squircle" con gradiente diagonale (c1 → c2) e un glifo vettoriale
// su griglia 48×48, composto da livelli (riempimento o tratto). Colore "ink" = segni
// scuri sul glifo bianco. Nessuna icona di terzi è copiata.
QtObject {
    id: g

    // Forma di base (superellisse approssimata) su 48×48.
    readonly property string squircle: "M24 0C40.8 0 48 7.2 48 24S40.8 48 24 48 0 40.8 0 24 7.2 0 24 0z"

    function circle(cx, cy, r) {
        return "M" + cx + " " + (cy - r) + "a" + r + " " + r + " 0 1 1 0 " + (2 * r) + "a" + r + " " + r + " 0 1 1 0 " + (-2 * r) + "z"
    }

    readonly property string w: "#FFFFFF"

    readonly property var glyphs: ({
        "files": { c1: "#4FC3F7", c2: "#2563EB", ink: "#1E4FD8", layers: [
            { d: "M9 15a4 4 0 0 1 4-4h8.5l3.5 4H35a4 4 0 0 1 4 4v3H9z", fill: w, opacity: 0.72 },
            { d: "M9 20h30v13a4 4 0 0 1-4 4H13a4 4 0 0 1-4-4z", fill: w },
            { d: "M15 27.5h10", stroke: "ink", w: 2.6 } ] },
        "terminal": { c1: "#3B4A63", c2: "#0B1222", ink: "#0B1222", layers: [
            { d: "M9 12a4 4 0 0 1 4-4h22a4 4 0 0 1 4 4v24a4 4 0 0 1-4 4H13a4 4 0 0 1-4-4z", fill: "#060B16", opacity: 0.85 },
            { d: "M14 11.7a1.3 1.3 0 1 1 0 2.6a1.3 1.3 0 1 1 0-2.6zM18 11.7a1.3 1.3 0 1 1 0 2.6a1.3 1.3 0 1 1 0-2.6zM22 11.7a1.3 1.3 0 1 1 0 2.6a1.3 1.3 0 1 1 0-2.6z", fill: w, opacity: 0.45 },
            { d: "M15 21l5 4.5-5 4.5", stroke: "#5FE1F7", w: 3 },
            { d: "M24 31h9", stroke: w, w: 3 } ] },
        "settings": { c1: "#A3B1C6", c2: "#3F4C63", ink: "#334155", layers: [
            { d: "circle:24,24,12.4", stroke: w, w: 5, dash: [1.05, 1.1] },
            { d: "circle:24,24,10.4", fill: w },
            { d: "circle:24,24,4.4", fill: "ink" } ] },
        "store": { c1: "#F472B6", c2: "#7C3AED", ink: "#7C3AED", layers: [
            { d: "M19 19v-3.5a5 5 0 0 1 10 0V19", stroke: w, w: 3 },
            { d: "M12.5 18h23l-1.6 17.2A4 4 0 0 1 29.9 39H18.1a4 4 0 0 1-4-3.8z", fill: w },
            { d: "M24 23.5l1.4 3.6 3.6 1.4-3.6 1.4L24 33.5l-1.4-3.6-3.6-1.4 3.6-1.4z", fill: "ink" } ] },
        "browser": { c1: "#22D3EE", c2: "#6366F1", ink: "#4F46E5", layers: [
            { d: "circle:24,24,13", fill: w },
            { d: "M24 11c-4.5 4-6.5 8.5-6.5 13s2 9 6.5 13c4.5-4 6.5-8.5 6.5-13s-2-9-6.5-13z", stroke: "ink", w: 2 },
            { d: "M11.5 24h25M13.6 17.5h20.8M13.6 30.5h20.8", stroke: "ink", w: 2 } ] },
        "update": { c1: "#34D399", c2: "#0EA5E9", ink: "#0369A1", layers: [
            { d: "M13.5 24A10.5 10.5 0 0 1 31.4 16.6", stroke: w, w: 3.6 },
            { d: "M35 20.2L33.1 13.7L28.5 18.3z", fill: w },
            { d: "M34.5 24A10.5 10.5 0 0 1 16.6 31.4", stroke: w, w: 3.6 },
            { d: "M13 27.8L14.9 34.3L19.5 29.7z", fill: w },
            { d: "circle:24,24,2.6", fill: w } ] },
        "security": { c1: "#60A5FA", c2: "#4338CA", ink: "#3730A3", layers: [
            { d: "M24 9.5l12 4.6v8.6c0 7.8-5 13.4-12 16.3-7-2.9-12-8.5-12-16.3v-8.6z", fill: w },
            { d: "M18.5 24.2l4 4 7.2-8", stroke: "ink", w: 3.2 } ] },
        "performance": { c1: "#FB923C", c2: "#E11D48", ink: "#BE123C", layers: [
            { d: "M12 30A12 12 0 0 1 36 30", stroke: w, w: 4, opacity: 0.4 },
            { d: "M12 30A12 12 0 0 1 30 19.6", stroke: w, w: 4 },
            { d: "M24 30L31.5 22.5", stroke: w, w: 3 },
            { d: "circle:24,30,3.2", fill: w } ] },
        "network": { c1: "#22D3EE", c2: "#0D9488", ink: "#0F766E", layers: [
            { d: "M16 31L24 16M24 16L32 31M16 31H32", stroke: w, w: 2.6, opacity: 0.85 },
            { d: "circle:24,16,4.4", fill: w },
            { d: "circle:16,31,4.4", fill: w },
            { d: "circle:32,31,4.4", fill: w },
            { d: "circle:24,16,1.8", fill: "ink" } ] },
        "storage": { c1: "#A78BFA", c2: "#6D28D9", ink: "#5B21B6", layers: [
            { d: "M12 15a3 3 0 0 1 3-3h18a3 3 0 0 1 3 3v1a3 3 0 0 1-3 3H15a3 3 0 0 1-3-3z", fill: w },
            { d: "M12 23.5a3 3 0 0 1 3-3h18a3 3 0 0 1 3 3v1a3 3 0 0 1-3 3H15a3 3 0 0 1-3-3z", fill: w, opacity: 0.9 },
            { d: "M12 32a3 3 0 0 1 3-3h18a3 3 0 0 1 3 3v1a3 3 0 0 1-3 3H15a3 3 0 0 1-3-3z", fill: w, opacity: 0.8 },
            { d: "circle:31,15.5,1.5", fill: "ink" }, { d: "circle:31,24,1.5", fill: "ink" }, { d: "circle:31,32.5,1.5", fill: "ink" } ] },
        "media": { c1: "#F43F5E", c2: "#F59E0B", ink: "#E11D48", layers: [
            { d: "M11 15a4 4 0 0 1 4-4h18a4 4 0 0 1 4 4v18a4 4 0 0 1-4 4H15a4 4 0 0 1-4-4z", fill: w },
            { d: "M21 18.5v11l9-5.5z", fill: "ink", stroke: "ink", w: 1.5 } ] },
        "office": { c1: "#60A5FA", c2: "#2563EB", ink: "#1D4ED8", layers: [
            { d: "M15 9h12l8 8v19a3 3 0 0 1-3 3H15a3 3 0 0 1-3-3V12a3 3 0 0 1 3-3z", fill: w },
            { d: "M27 9v6a2 2 0 0 0 2 2h6z", fill: "ink", opacity: 0.35 },
            { d: "M17 23h14M17 28h14M17 33h9", stroke: "ink", w: 2.2 } ] },
        "gaming": { c1: "#A3E635", c2: "#16A34A", ink: "#15803D", layers: [
            { d: "M15.5 17h17a6.5 6.5 0 0 1 6.3 5l1.6 7.4a4.6 4.6 0 0 1-7.9 4.1L29.8 30h-11.6l-2.7 3.5a4.6 4.6 0 0 1-7.9-4.1L9.2 22a6.5 6.5 0 0 1 6.3-5z", fill: w },
            { d: "M16.5 21v6M13.5 24h6", stroke: "ink", w: 2.4 },
            { d: "circle:30.5,22,1.7", fill: "ink" }, { d: "circle:33.7,25.2,1.7", fill: "ink" } ] },
        "developer": { c1: "#818CF8", c2: "#312E81", ink: "#312E81", layers: [
            { d: "M18 16l-7 8 7 8", stroke: w, w: 3.4 },
            { d: "M30 16l7 8-7 8", stroke: w, w: 3.4 },
            { d: "M26.5 13l-5 22", stroke: "#5FE1F7", w: 3 } ] },
        "display": { c1: "#2DD4BF", c2: "#2563EB", ink: "#1D4ED8", layers: [
            { d: "M9 13a3 3 0 0 1 3-3h24a3 3 0 0 1 3 3v15a3 3 0 0 1-3 3H12a3 3 0 0 1-3-3z", fill: w },
            { d: "M13 24c4-5 7-5 11 0s7 5 11 0", stroke: "ink", w: 2.2 },
            { d: "M20 31h8l1.2 5H18.8z", fill: w, opacity: 0.85 },
            { d: "M16 38h16", stroke: w, w: 2.6 } ] },
        "audio": { c1: "#F472B6", c2: "#BE185D", ink: "#9D174D", layers: [
            { d: "M14 21v6M19 16v16M24 12v24M29 18v12M34 21v6", stroke: w, w: 3.4 } ] },
        "accessibility": { c1: "#38BDF8", c2: "#1D4ED8", ink: "#1D4ED8", layers: [
            { d: "circle:24,24,13.5", stroke: w, w: 2.6 },
            { d: "circle:24,16.5,2.7", fill: w },
            { d: "M16.5 21L24 22.8L31.5 21M24 22.8v5.4M24 28.2l-4 6.8M24 28.2l4 6.8", stroke: w, w: 2.6 } ] },
        "ai": { c1: "#C084FC", c2: "#22D3EE", ink: "#7C3AED", layers: [
            { d: "M22 10l2.6 7.4L32 20l-7.4 2.6L22 30l-2.6-7.4L12 20l7.4-2.6z", fill: w },
            { d: "M32.5 27l1.3 3.7 3.7 1.3-3.7 1.3-1.3 3.7-1.3-3.7-3.7-1.3 3.7-1.3z", fill: w, opacity: 0.8 } ] },
        "texteditor": { c1: "#FBBF24", c2: "#F97316", ink: "#C2410C", layers: [
            { d: "M12 12a3 3 0 0 1 3-3h14a3 3 0 0 1 3 3v24a3 3 0 0 1-3 3H15a3 3 0 0 1-3-3z", fill: w },
            { d: "M16 16h11M16 21h11M16 26h6", stroke: "ink", w: 2.2 },
            { d: "M35 21l3 3-9.5 9.5-4 1 1-4z", fill: "ink" } ] },
        "spreadsheet": { c1: "#4ADE80", c2: "#15803D", ink: "#166534", layers: [
            { d: "M12 12a3 3 0 0 1 3-3h18a3 3 0 0 1 3 3v24a3 3 0 0 1-3 3H15a3 3 0 0 1-3-3z", fill: w },
            { d: "M12 17h24M12 24h24M12 31h24M20.5 9v30M28.5 9v30", stroke: "ink", w: 1.6, opacity: 0.55 },
            { d: "M12 12a3 3 0 0 1 3-3h18a3 3 0 0 1 3 3v5H12z", fill: "ink", opacity: 0.85 } ] },
        "presentation": { c1: "#FDBA74", c2: "#EA580C", ink: "#C2410C", layers: [
            { d: "M9 12a2 2 0 0 1 2-2h26a2 2 0 0 1 2 2v18a2 2 0 0 1-2 2H11a2 2 0 0 1-2-2z", fill: w },
            { d: "M17 26v-5M22 26v-9M27 26v-7M32 26v-11", stroke: "ink", w: 3 },
            { d: "M24 32v5M19 38.5l5-4 5 4", stroke: w, w: 2.6 } ] },
        "drawing": { c1: "#FDE047", c2: "#EAB308", ink: "#A16207", layers: [
            { d: "circle:19,20,8", fill: w },
            { d: "M26 38l7-12 7 12z", fill: w, opacity: 0.9 },
            { d: "M10 30h12v8H10z", fill: "ink", opacity: 0.8 } ] },
        "calculator": { c1: "#FB7185", c2: "#9333EA", ink: "#7E22CE", layers: [
            { d: "M14 9h20a3 3 0 0 1 3 3v24a3 3 0 0 1-3 3H14a3 3 0 0 1-3-3V12a3 3 0 0 1 3-3z", fill: w },
            { d: "M15.5 13h17a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1h-17a1 1 0 0 1-1-1v-4a1 1 0 0 1 1-1z", fill: "ink", opacity: 0.9 },
            { d: "M15 23h4v4h-4zM22 23h4v4h-4zM29 23h4v4h-4zM15 30h4v4h-4zM22 30h4v4h-4zM29 30h4v4h-4z", fill: "ink", opacity: 0.55 } ] },
        "calendar": { c1: "#F87171", c2: "#DC2626", ink: "#DC2626", layers: [
            { d: "M11 15a3 3 0 0 1 3-3h20a3 3 0 0 1 3 3v19a3 3 0 0 1-3 3H14a3 3 0 0 1-3-3z", fill: w },
            { d: "M11 15a3 3 0 0 1 3-3h20a3 3 0 0 1 3 3v4H11z", fill: "ink", opacity: 0.85 },
            { d: "M18 9.5v5M30 9.5v5", stroke: w, w: 2.6 },
            { d: "circle:17.5,25.5,1.6", fill: "ink" }, { d: "circle:24,25.5,1.6", fill: "ink" }, { d: "circle:30.5,25.5,1.6", fill: "ink" },
            { d: "circle:17.5,31.5,1.6", fill: "ink" }, { d: "circle:24,31.5,1.6", fill: "ink", opacity: 0.5 } ] },
        "photos": { c1: "#FDBA74", c2: "#EC4899", ink: "#DB2777", layers: [
            { d: "M10 14a4 4 0 0 1 4-4h20a4 4 0 0 1 4 4v20a4 4 0 0 1-4 4H14a4 4 0 0 1-4-4z", fill: w },
            { d: "M13.5 34.5l7.5-9.5 5 6 3-3.5 5.5 7z", fill: "ink" },
            { d: "circle:29.5,18.5,3.2", fill: "#F59E0B" } ] },
        "mail": { c1: "#60A5FA", c2: "#06B6D4", ink: "#0284C7", layers: [
            { d: "M10 16a3 3 0 0 1 3-3h22a3 3 0 0 1 3 3v16a3 3 0 0 1-3 3H13a3 3 0 0 1-3-3z", fill: w },
            { d: "M11.5 15.5L24 25l12.5-9.5", stroke: "ink", w: 2.4 } ] },
        "music": { c1: "#F472B6", c2: "#A855F7", ink: "#7E22CE", layers: [
            { d: "M20 31V14.5l13-3V28", stroke: w, w: 3 },
            { d: "circle:16.5,31,4", fill: w }, { d: "circle:29.5,28,4", fill: w } ] },
        "chat": { c1: "#4ADE80", c2: "#0EA5E9", ink: "#0284C7", layers: [
            { d: "M12 15a4 4 0 0 1 4-4h16a4 4 0 0 1 4 4v11a4 4 0 0 1-4 4h-9l-6.5 5.5V30H16a4 4 0 0 1-4-4z", fill: w },
            { d: "circle:18.5,20.5,1.9", fill: "ink" }, { d: "circle:24,20.5,1.9", fill: "ink" }, { d: "circle:29.5,20.5,1.9", fill: "ink" } ] },
        "video": { c1: "#F87171", c2: "#7C3AED", ink: "#6D28D9", layers: [
            { d: "M9 17a3 3 0 0 1 3-3h15a3 3 0 0 1 3 3v14a3 3 0 0 1-3 3H12a3 3 0 0 1-3-3z", fill: w },
            { d: "M32 21.5l7-4v13l-7-4z", fill: w },
            { d: "circle:19.5,24,3.6", fill: "ink", opacity: 0.85 } ] },
        "help": { c1: "#60A5FA", c2: "#7C3AED", ink: "#5B21B6", layers: [
            { d: "circle:24,24,13", fill: w },
            { d: "M19.5 19.5a4.5 4.5 0 1 1 6.6 4c-1.4.8-2.1 1.7-2.1 3.2v.8", stroke: "ink", w: 3 },
            { d: "circle:24,32.6,1.9", fill: "ink" } ] },
        "archive": { c1: "#FBBF24", c2: "#B45309", ink: "#92400E", layers: [
            { d: "M10 15a2 2 0 0 1 2-2h24a2 2 0 0 1 2 2v5H10z", fill: w },
            { d: "M12 21h24v14a3 3 0 0 1-3 3H15a3 3 0 0 1-3-3z", fill: w, opacity: 0.9 },
            { d: "M24 13v4M24 21v3M24 27v3", stroke: "ink", w: 2.2 },
            { d: "M20 33h8", stroke: "ink", w: 2.4 } ] },
        "logs": { c1: "#94A3B8", c2: "#0F766E", ink: "#0F766E", layers: [
            { d: "M15 9h18a3 3 0 0 1 3 3v24a3 3 0 0 1-3 3H15a3 3 0 0 1-3-3V12a3 3 0 0 1 3-3z", fill: w },
            { d: "M16.5 16h3M22.5 16h9M16.5 22h3M22.5 22h9M16.5 28h3M22.5 28h6M16.5 34h3", stroke: "ink", w: 2.2 } ] },
        "chars": { c1: "#FDE047", c2: "#F97316", ink: "#9A3412", layers: [
            { d: "circle:24,24,13", fill: w },
            { d: "circle:19.5,21,1.9", fill: "ink" }, { d: "circle:28.5,21,1.9", fill: "ink" },
            { d: "M18 27.5c3 4.2 9 4.2 12 0", stroke: "ink", w: 2.4 } ] },
        "bug": { c1: "#F87171", c2: "#9F1239", ink: "#9F1239", layers: [
            { d: "M16 22h-5M16 29h-5M32 22h5M32 29h5M18 16l-3-3M30 16l3-3", stroke: w, w: 2.4 },
            { d: "M24 15c5 0 8 4 8 10v3c0 5-3.6 9-8 9s-8-4-8-9v-3c0-6 3-10 8-10z", fill: w },
            { d: "M24 18v17M17 25h14", stroke: "ink", w: 2 } ] },
        "phone": { c1: "#34D399", c2: "#2563EB", ink: "#1E40AF", layers: [
            { d: "M18 9h12a3 3 0 0 1 3 3v24a3 3 0 0 1-3 3H18a3 3 0 0 1-3-3V12a3 3 0 0 1 3-3z", fill: w },
            { d: "M18 13h12v18H18z", fill: "ink", opacity: 0.85 },
            { d: "circle:24,35,1.5", fill: "ink" } ] },
        "generic": { c1: "#94A3B8", c2: "#6366F1", ink: "#4F46E5", layers: [
            { d: "M24 10l12 6.5-12 6.5-12-6.5z", fill: w },
            { d: "M12 18.5l11 6v13l-11-6z", fill: w, opacity: 0.78 },
            { d: "M25 24.5l11-6v13l-11 6z", fill: w, opacity: 0.55 } ] }
    })

    readonly property var keys: Object.keys(glyphs)

    // Regole di associazione (ordine = priorità): parole chiave su nome, id .desktop e nome icona.
    readonly property var rules: [
        ["update", ["update", "aggiorn"]],
        ["help", ["help center", "khelpcenter", "guida", "manuale"]],
        ["bug", ["crash", "drkonqi", "debug"]],
        ["logs", ["journal", "ksystemlog", "log viewer", "registro eventi"]],
        ["phone", ["kde connect", "kdeconnect", "phone", "telefono"]],
        ["chars", ["emoji", "charselect", "caratteri speciali"]],
        ["archive", [" ark ", "archiv", "compress", "zip "]],
        ["security", ["security", "sicurezza", "firewall", "kwallet", "password", "keepass"]],
        ["performance", ["perform", "system monitor", "systemmonitor", "monitor di sistema", "ksysguard", "htop"]],
        ["network", ["network", "rete", "nm-connection", "connessioni"]],
        ["storage", ["storage", "disk", "partition", "filelight"]],
        ["accessibility", ["accessib", "orca"]],
        ["photos", ["imagemagick", "gimp", "krita", "digikam", "gwenview"]],
        ["display", ["display", "schermo", "kscreen"]],
        ["audio", ["audio", "pavucontrol", "sound", "pipewire", "suono"]],
        ["gaming", ["gaming", "game", "steam", "lutris", "heroic", "gioc"]],
        ["developer", ["develop", "kdevelop", "vscode", "visual studio", " ide", "gitg", "code"]],
        ["store", ["store", "discover", "software", "flathub", "negozio"]],
        ["browser", ["browser", "firefox", "chrom", "epiphany", "falkon", "web"]],
        ["files", ["file manager", "files", "dolphin", "nautilus", "nemo", "thunar", "gestore file"]],
        ["terminal", ["terminal", "konsole", "console", "xterm", "ptyxis"]],
        ["settings", ["settings", "impostazioni", "systemsettings", "preferenze"]],
        ["calculator", ["calculator", "calcolatrice", "kcalc", "qalculate"]],
        ["spreadsheet", ["calc", "spreadsheet", "foglio di calcolo"]],
        ["presentation", ["impress", "presentation", "presentazion"]],
        ["drawing", ["libreoffice draw", "inkscape", "drawing", "disegno"]],
        ["office", ["office", "writer", "libreoffice", "document", "okular", "pdf", "impress"]],
        ["calendar", ["calendar", "calendario", "korganizer", "merkuro"]],
        ["photos", ["imagemagick", "photo", "foto", "gwenview", "image", "immagin", "gimp", "krita", "digikam"]],
        ["mail", ["mail", "thunderbird", "kmail", "posta"]],
        ["music", ["music", "musica", "elisa", "rhythmbox", "spotify", "amarok"]],
        ["chat", ["chat", "telegram", "discord", "element", "signal", "neochat", "slack"]],
        ["video", ["camera", "kamoso", "cheese", "video", "kdenlive", "obs"]],
        ["media", ["media", "player", "vlc", "mpv", "dragon", "haruna", "totem"]],
        ["texteditor", ["kate", "kwrite", "gedit", "vim", "emacs", "editor", "text", "testo"]],
        ["ai", ["assistente", "assistant", "llm", "omni ai"]]
    ]
    readonly property var categoryRules: [
        ["Development", "developer"], ["Game", "gaming"], ["Graphics", "photos"], ["Office", "office"],
        ["Audio", "music"], ["Video", "video"], ["AudioVideo", "media"], ["WebBrowser", "browser"],
        ["Email", "mail"], ["Chat", "chat"], ["Network", "browser"], ["Settings", "settings"],
        ["System", "settings"], ["Utility", "generic"]
    ]

    function resolve(name, desktopId, iconName, categories) {
        const hay = " " + [name, desktopId, iconName].map(s => String(s || "").toLowerCase()).join(" ") + " "
        for (let i = 0; i < rules.length; ++i)
            for (let k = 0; k < rules[i][1].length; ++k)
                if (hay.indexOf(rules[i][1][k]) >= 0) return rules[i][0]
        const cats = categories || []
        for (let j = 0; j < categoryRules.length; ++j)
            for (let c = 0; c < cats.length; ++c)
                if (cats[c] === categoryRules[j][0]) return categoryRules[j][1]
        return "generic"
    }
    function glyph(key) { return glyphs[key] !== undefined ? glyphs[key] : glyphs["generic"] }
}
