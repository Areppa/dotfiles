-----------------------
--- BINDS & AUTORUN ---
-----------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

------------------------
--- DEFAULT PROGRAMS ---
------------------------

local terminal = "kitty"
local task_manager = "btop"
local bluetooth_manager = "bluetui"
local network_manager = "nmtui"
local fileManager = "lf"
local fileManagerGui = "nautilus --no-desktop -w"
local audio_control = "pavucontrol -t 3"
local browser = "helium-browser"
local private_browser = browser .. " --incognito"
local tor_browser = "torbrowser-launcher"
local menu = "ROFI_LIST=true rofi -show drun"
local text_editor = "zeditor"
local text_editor_simple = "gnome-text-editor"
local screenshot = "hyprshot -o ~/Pictures/Screenshots/Hyprland"
local calculator = "gnome-calculator"
local vm_manager = "virt-manager"
local rgb_controller = "flatpak run org.openrgb.OpenRGB -p"
local clipboard_history = "cliphist list   | ROFI_LIST=true rofi -dmenu -p \"\" -display-columns 2   | cliphist decode   | wl-copy"

---------------
--- AUTORUN ---
---------------

hl.on("hyprland.start", function()
    -- HYPRLAND & SYSTEM
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("hyprlock")
    hl.exec_cmd("waybar & swaync & hypridle & hyprpaper")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Visible apps
    hl.exec_cmd(browser, { workspace = "5 silent" })
    hl.exec_cmd("flatpak run dev.vencord.Vesktop", { workspace = "2 silent" })
    hl.exec_cmd("spotify", { workspace = "2 silent" })
    hl.exec_cmd("flatpak run md.obsidian.Obsidian", { workspace = "3 silent" })

    -- Background apps
    hl.exec_cmd("flatpak run org.openrgb.OpenRGB --startminimized")
    hl.exec_cmd("steam -silent -console")
    hl.exec_cmd("udiskie")
    hl.exec_cmd("/bin/bash -c \"sleep 5 && flatpak run com.github.wwmm.easyeffects -w\"")
    hl.exec_cmd("/opt/duplicati/duplicati-server")
end)

-------------
--- BINDS ---
-------------

-- Main programs
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(terminal .. " " .. fileManager))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(fileManagerGui))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd(private_browser))
hl.bind(mainMod .. " + SHIFT + CTRL + N", hl.dsp.exec_cmd(tor_browser))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(calculator))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("flatpak run md.obsidian.Obsidian"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(text_editor))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(text_editor_simple))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(vm_manager))

-- Settings, config, e.g.
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(audio_control))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd(clipboard_history))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd(terminal .. " " .. bluetooth_manager))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(terminal .. " " .. network_manager))
hl.bind("CTRL + SHIFT + ESCAPE", hl.dsp.exec_cmd(terminal .. " " .. task_manager))
hl.bind(mainMod .. " + CTRL + SHIFT + P", hl.dsp.exec_cmd(terminal .. " ping 1.1.1.1"))

-- Change OpenRGB profile
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd(rgb_controller .. "\"Off\""))
hl.bind(mainMod .. " + CTRL + I", hl.dsp.exec_cmd(rgb_controller .. "\"Default\""))

-- Screenshots
hl.bind("PRINT", hl.dsp.exec_cmd(screenshot .. " -m window"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(screenshot .. " -m region"))
hl.bind("CTRL + SHIFT + PRINT", hl.dsp.exec_cmd(screenshot .. " -m output"))

-- Game launch (disables 2nd screen for some time until the game launches, "Temporary")
hl.bind(mainMod .. " + CTRL + G", hl.dsp.exec_cmd("~/.config/scripts/game_launch.sh"))


-------------------------
--- WINDOW MANAGEMENT ---
-------------------------

-- Main window management & system binds
hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + CTRL + SHIFT + M", hl.dsp.exit())

-- Move focus/workspace with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + CTRL + left", hl.dsp.focus({ workspace = "e-1" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())


----------------------------
--- AUDIO, MEDIA, SCREEN ---
----------------------------

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Audio switching using STOP media button
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("~/.config/scripts/change_audio.sh"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("~/.config/scripts/change_audio.sh"))

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
