---------------------
--- LOOK AND FEEL ---
---------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 8,
        border_size = 3,
        col = {
            active_border = "rgba(800080ff)",
            inactive_border = "rgba(595959ff)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        fullscreen_opacity = 1.0,
        inactive_opacity = 0.96,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
        blur = {
            enabled = true,
            size = 5,
            passes = 1,
            vibrancy = 0.1696,
            brightness = 0.9,
        },
    },

    dwindle = {
        preserve_split = true, -- You probably want this
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 1, -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo = false, -- If true disables the random hyprland logo / anime girl background. :(
    },
})
