-------------
--- INPUT ---
-------------

hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})

hl.gesture({
    fingers = 4,
    direction = "swipe",
    action = "resize",
})

hl.config({
    input = {
        kb_layout = "fi",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",
        follow_mouse = 1,
        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.
        accel_profile = "flat",
        numlock_by_default = true,
        touchpad = {
            natural_scroll = true,
        },
    },
})
