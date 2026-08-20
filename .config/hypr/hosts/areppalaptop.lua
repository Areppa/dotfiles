-----------------------
--- WORKSPACE RULES ---
-----------------------

hl.workspace_rule({
    workspace = 1,
    monitor = "eDP-1",
})

hl.workspace_rule({
    workspace = 2,
    monitor = "eDP-1",
})

hl.workspace_rule({
    workspace = 3,
    monitor = "eDP-1",
})

hl.workspace_rule({
    workspace = 5,
    monitor = "HDMI-A-1",
})

hl.workspace_rule({
    workspace = 10,
    monitor = "HDMI-A-1",
})

---------------
--- AUTORUN ---
---------------

hl.on("hyprland.start", function()
    -- Background apps
    hl.exec_cmd("udiskie")
    hl.exec_cmd("/bin/bash -c \"sleep 5 && flatpak run com.github.wwmm.easyeffects -w\"")
end)
