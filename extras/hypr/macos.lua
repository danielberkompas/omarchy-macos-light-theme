-- omarchy-macos-light: macOS-style desktop for Omarchy.
-- Loaded from ~/.config/hypr/hyprland.lua (install.sh adds the require line).
-- Each piece lives in ~/.config/hypr/macos/; comment out any line below to
-- turn that piece off.

require("hypr.macos.input")      -- ⌘ key layout, trackpad, three-finger swipe
require("hypr.macos.bindings")   -- ⌘C/⌘V/⌘W/⌘Q/⌘Space/⌘Tab/⇧⌘4 … shortcuts
require("hypr.macos.minimize")   -- ⌘M minimize to the dock with a genie animation
require("hypr.macos.looknfeel")  -- rounded corners, shadows, blur, animations
require("hypr.macos.titlebars")  -- title bars with red/yellow/green buttons
require("hypr.macos.autostart")  -- dock, genie, Chromium traffic lights
