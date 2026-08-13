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
    workspace = 5,
    monitor = "DP-2",
})

hl.workspace_rule({
    workspace = 10,
    monitor = "DP-2",
})
