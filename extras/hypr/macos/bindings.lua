-- ════════════════════════════════════════════════════════════════════════════
-- macOS-style shortcuts
--
-- input.lua swaps Left Alt/Super, so the key beside the spacebar is SUPER and
-- behaves like ⌘ Command. These bindings make ⌘+key do what it does on a Mac
-- by sending the Linux Ctrl+key equivalent to the focused app. In terminals,
-- where Ctrl+key means something else, they do the sensible terminal thing.
-- ════════════════════════════════════════════════════════════════════════════

-- Same technique as Omarchy's universal copy/paste (default/hypr/bindings/clipboard.lua).
local function send_shortcut(mods, key)
  hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
  hl.timer(function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
  end, { timeout = 50, type = "oneshot" })
end

local function is_terminal()
  local window = hl.get_active_window()
  if not window then
    return false
  end
  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then
      return true
    end
  end
  return false
end

-- mac_key(mods, key, terminal_action): send Ctrl-equivalent to normal apps;
-- in terminals run terminal_action (a function), or do nothing if nil.
local function mac_key(mods, key, terminal_action)
  return function()
    if is_terminal() then
      if terminal_action then
        terminal_action()
      end
    else
      send_shortcut(mods, key)
    end
  end
end

local function close_window()
  hl.dispatch(hl.dsp.window.close())
end

local function new_terminal()
  hl.exec_cmd("omarchy-launch-terminal")
end

-- Move Omarchy bindings out of the way of the Mac shortcuts below.
hl.unbind("SUPER + T")          -- was: toggle floating
hl.unbind("SUPER + F")          -- was: full screen
hl.unbind("SUPER + CTRL + F")   -- was: tiled full screen
hl.unbind("SUPER + S")          -- was: toggle scratchpad
hl.unbind("SUPER + L")          -- was: toggle workspace layout
hl.unbind("SUPER + P")          -- was: pseudo window
hl.unbind("SUPER + W")          -- was: close window
hl.unbind("SUPER + SPACE")      -- was: Omarchy menu
hl.unbind("SUPER + ALT + SPACE") -- was: apps menu
hl.unbind("SUPER + TAB")        -- was: next workspace
hl.unbind("SUPER + SHIFT + TAB") -- was: previous workspace
hl.unbind("SUPER + CTRL + Q")   -- was: calculator
hl.unbind("SUPER + SHIFT + code:12") -- was: move window to workspace 3
hl.unbind("SUPER + SHIFT + code:13") -- was: move window to workspace 4
hl.unbind("SUPER + SHIFT + code:14") -- was: move window to workspace 5

o.bind("SUPER + T", "New tab", mac_key("CTRL", "T", new_terminal))
o.bind("SUPER + N", "New window", mac_key("CTRL", "N", new_terminal))
o.bind("SUPER + W", "Close tab", mac_key("CTRL", "W", close_window))
o.bind("SUPER + Q", "Quit (close window)", close_window)
o.bind("SUPER + A", "Select all", mac_key("CTRL", "A"))
o.bind("SUPER + Z", "Undo", mac_key("CTRL", "Z"))
o.bind("SUPER + SHIFT + Z", "Redo", mac_key("CTRL + SHIFT", "Z"))
o.bind("SUPER + F", "Find", mac_key("CTRL", "F", function() send_shortcut("CTRL + SHIFT", "R") end))
o.bind("SUPER + S", "Save", mac_key("CTRL", "S"))
o.bind("SUPER + R", "Reload", mac_key("CTRL", "R"))
o.bind("SUPER + L", "Address bar", mac_key("CTRL", "L"))
o.bind("SUPER + P", "Print", mac_key("CTRL", "P"))
o.bind("SUPER + SHIFT + T", "Reopen closed tab", mac_key("CTRL + SHIFT", "T"))

-- ⌘Space = Spotlight-style app launcher; ⌥⌘Space = Omarchy menu.
o.bind("SUPER + SPACE", "App launcher", "omarchy-menu toggle apps")
o.bind("SUPER + ALT + SPACE", "Omarchy menu", "omarchy-menu toggle")

-- ⌘Tab / ⇧⌘Tab = app switcher. See switcher.lua.
-- Ctrl+⌘←/→ = previous/next desktop (also: three-finger swipe).
o.bind("SUPER + CTRL + ALT + LEFT", "Previous desktop", hl.dsp.focus({ workspace = "e-1" }))
o.bind("SUPER + CTRL + ALT + RIGHT", "Next desktop", hl.dsp.focus({ workspace = "e+1" }))

-- ⌘M = minimize to the dock; ⌥⌘M = restore. See minimize.lua.

-- Ctrl+⌘F = full screen (Mac standard). Former SUPER+F variants moved here too.
o.bind("SUPER + CTRL + F", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
o.bind("SUPER + CTRL + SHIFT + F", "Tiled full screen", "omarchy-hyprland-window-tiled-fullscreen-toggle")

-- Relocated Omarchy window-manager shortcuts.
o.bind("SUPER + ALT + T", "Toggle window floating/tiling", hl.dsp.window.float({ action = "toggle" }))
o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")
o.bind("SUPER + CTRL + ALT + S", "Toggle scratchpad", hl.dsp.workspace.toggle_special("scratchpad"))

-- ⇧⌘3 / ⇧⌘4 / ⇧⌘5 = screenshots, like macOS.
o.bind("SUPER + SHIFT + code:12", "Screenshot full screen", "omarchy-capture-screenshot fullscreen")
o.bind("SUPER + SHIFT + code:13", "Screenshot region", "omarchy-capture-screenshot region")
o.bind("SUPER + SHIFT + code:14", "Capture menu", "omarchy-menu toggle capture")

-- Ctrl+⌘Q = lock screen; ⌥⌘Esc = force quit the focused app.
o.bind("SUPER + CTRL + Q", "Lock screen", "omarchy-system-lock")
o.bind("SUPER + ALT + ESCAPE", "Force quit app", "kill -9 $(hyprctl activewindow -j | jq -r .pid)")
