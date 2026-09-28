-- macOS-style ⌘Tab app switcher.
--
-- Hold ⌘ and press Tab to bring up the windows on this desktop, most recently
-- used first; keep pressing Tab (or ⇧Tab to go back) to move the highlight, and
-- let go of ⌘ to switch. Esc cancels, and clicking an icon switches to it.
-- A quick ⌘Tab tap flips between the two most recent windows.
--
-- The switcher itself is drawn by ~/.config/quickshell/app-switcher (started in
-- autostart.lua); this file tells it what to show with Hyprland custom events.

local mode = require("hypr.macos.mode")

-- XKB keycodes: the physical keys ⌘ can be on (Left Alt is ⌘ after input.lua's
-- swap; Super keys cover keyboards without it), and Esc.
local COMMAND_KEYS = { [64] = true, [133] = true, [134] = true }
local ESCAPE = 9

local state = nil -- { windows = { address, … }, index } while the switcher is up

local function emit(message)
  hl.dispatch(hl.dsp.event("switcher " .. message))
end

-- Windows on the current desktop, most recently focused first.
local function recent_windows()
  local workspace = hl.get_active_workspace()
  if not workspace then
    return {}
  end
  local windows = {}
  for _, window in ipairs(hl.get_workspace_windows(workspace.id) or {}) do
    if window.mapped then
      table.insert(windows, window)
    end
  end
  table.sort(windows, function(a, b) return a.focus_history_id < b.focus_history_id end)
  return windows
end

local function finish(switch)
  local current = state
  state = nil
  if not current then
    return
  end
  emit("hide")
  local address = switch and current.windows[current.index]
  if address and hl.get_window("address:" .. address) then
    hl.dispatch(hl.dsp.focus({ window = "address:" .. address }))
    hl.dispatch(hl.dsp.window.bring_to_top())
  end
end

local function step(forward)
  return function()
    if state then
      state.index = (state.index - 1 + (forward and 1 or -1)) % #state.windows + 1
      emit("select " .. state.index)
      return
    end

    local windows = recent_windows()
    if #windows < 2 then
      return
    end
    local addresses, items = {}, {}
    for _, window in ipairs(windows) do
      table.insert(addresses, window.address)
      local class = (window.class ~= "" and window.class or window.initial_class or "?")
      class = class:gsub("%%", "%%25"):gsub(" ", "%%20")
      table.insert(items, window.address .. "=" .. class)
    end
    state = { windows = addresses, index = forward and 2 or #addresses }
    emit("show " .. mode.pick("light", "dark") .. " " .. state.index .. " " .. table.concat(items, " "))
  end
end

hl.on("input.keyboard.key", function(keycode, _, pressed)
  if not state then
    return
  end
  if pressed == 0 and COMMAND_KEYS[keycode] then
    finish(true)
  elseif pressed == 1 and keycode == ESCAPE then
    finish(false)
  end
end)

-- For clicks on the switcher's icons.
function app_switcher_pick(index)
  if state and state.windows[index] then
    state.index = index
    finish(true)
  end
end

o.bind("SUPER + TAB", "Next window", step(true))
o.bind("SUPER + SHIFT + TAB", "Previous window", step(false))
