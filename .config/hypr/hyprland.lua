----------------------------------------
---  Areppa's Hyprland configuration ---
----------------------------------------

--------------------
--- Source files ---
--------------------

require("hyprConf/animations")
require("hyprConf/binds_autostart")
require("hyprConf/input")
require("hyprConf/lookAndFeel")
require("hyprConf/monitors")
require("hyprConf/permissions")
require("hyprConf/windowRules")

-------------------------------
--- Device specific configs ---
-------------------------------
-- Loads device specific config

hl.on("hyprland.start", function()
    -- Create symlink from hostname -> localconfig
    hl.exec_cmd("~/.config/scripts/hyprland_device_specific.sh")
end)

require("hyprConf/localconfig")
