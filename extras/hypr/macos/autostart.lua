-- Background helpers for the macOS-style desktop.

-- The dock itself is ODock, an Omarchy shell plugin that starts with the shell.

-- Genie minimize/restore animation daemon (see minimize.lua).
o.launch_on_start("qs -p " .. os.getenv("HOME") .. "/.config/quickshell/genie")

-- Traffic-light buttons over Chromium's tab strip (see titlebars.lua).
o.launch_on_start("qs -p " .. os.getenv("HOME") .. "/.config/quickshell/chrome-lights")

-- Load Hyprland plugins (hyprbars title bars), then reload so titlebars.lua applies.
o.exec_on_start("hyprpm reload -n && hyprctl reload")
