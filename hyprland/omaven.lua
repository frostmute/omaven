-- Omaven: Hyprland Window Rules & Keybindings
-- Place or require this in ~/.config/hypr/hyprland.lua: require("hypr.omaven")

o.window({ class = "^org.quickshell$", title = "^Omaven — Aven Task Manager$" }, {
  tag = "+floating-window",
  size = { 1040, 700 },
  center = true,
})

-- Global hotkey to toggle the Omaven desktop window
o.bind("SUPER + ALT + A", "Omaven: toggle desktop window", "omarchy-shell shell toggle omaven")
