----------------
--- MONITORS ---
----------------

hl.monitor({
    output = "DVI-D-1",
    mode = "1680x1050@59.95",
    position = "1920x0",
    scale = "1",
})

-----------------------
--- WORKSPACE RULES ---
-----------------------

hl.workspace_rule({
    workspace = 1,
    monitor = "DVI-D-1",
})

hl.workspace_rule({
    workspace = 2,
    monitor = "DVI-D-1",
})

hl.workspace_rule({
    workspace = 3,
    monitor = "DVI-D-1",
})

hl.workspace_rule({
    workspace = 4,
    monitor = "DVI-D-1",
})

hl.workspace_rule({
    workspace = 5,
    monitor = "DP-2",
})

hl.workspace_rule({
    workspace = 6,
    monitor = "DP-2",
})

hl.workspace_rule({
    workspace = 7,
    monitor = "DP-2",
})

hl.workspace_rule({
    workspace = 10,
    monitor = "DP-2",
})

---------------
--- AUTORUN ---
---------------

hl.on("hyprland.start", function()
    -- Visible apps
    hl.exec_cmd("spotify", { workspace = "2 silent" })

    -- Background apps
    hl.exec_cmd("flatpak run org.openrgb.OpenRGB --startminimized")
    hl.exec_cmd("steam -silent -console")
    hl.exec_cmd("udiskie")
    hl.exec_cmd("/bin/bash -c \"sleep 5 && flatpak run com.github.wwmm.easyeffects -w\"")
    hl.exec_cmd("/opt/duplicati/duplicati-server")
end)
