--------------------
--- WINDOW RULES ---
--------------------

hl.window_rule({
    match = {
        class = "vesktop",
    },
    workspace = "2",
})

hl.window_rule({
    name = "Calculator",
    match = {
        class = "org.gnome.Calculator",
    },
    size = "500 620",
    float = true,
})

hl.window_rule({
    name = "pavucontrol",
    match = {
        class = "org.pulseaudio.pavucontrol",
    },
    size = "1000 900",
    min_size = "450 700",
    float = true,
})

hl.window_rule({
    name = "Anki",
    match = {
        class = "net.ankiweb.Anki",
    },
    size = "800 950",
    min_size = "750 650",
    float = true,
    workspace = "10",
})

hl.window_rule({
    name = "Steam Games",
    match = {
        class = "^steam_app_\\d+$",
    },
    workspace = "10",
    fullscreen = true,
})

hl.window_rule({
    name = "Minecraft",
    match = {
        class = "(?i)\\bMinecraft\\b.*",
    },
    workspace = "10",
})

hl.window_rule({
    name = "Spotify",
    match = {
        class = "spotify",
    },
    workspace = "2",
    float = false,
    no_initial_focus = true,
    opacity = "1 override",
})

hl.window_rule({
    name = "Vesktop",
    match = {
        class = "vesktop",
    },
    no_initial_focus = true,
})

hl.window_rule({
    name = "Ghostty",
    match = {
        class = "com.mitchellh.ghostty",
    },
    opacity = "0.90 override",
})

hl.window_rule({
    name = "Gnome Text Editor",
    match = {
        class = "org.gnome.TextEditor",
    },
    workspace = "special",
    float = true,
    size = "800 700",
})
