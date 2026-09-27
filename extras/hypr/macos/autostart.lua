-- Background helpers for the macOS-style desktop.

-- The dock (see ~/.local/bin/macos-dock for its settings).
o.launch_on_start(os.getenv("HOME") .. "/.local/bin/macos-dock")

-- Genie minimize/restore animation daemon (see minimize.lua).
o.launch_on_start("qs -p " .. os.getenv("HOME") .. "/.config/quickshell/genie")

-- Traffic-light buttons over Chromium's tab strip (see titlebars.lua).
o.launch_on_start("qs -p " .. os.getenv("HOME") .. "/.config/quickshell/chrome-lights")

-- Load Hyprland plugins (hyprbars title bars), then reload so titlebars.lua applies.
o.exec_on_start("hyprpm reload -n && hyprctl reload")
