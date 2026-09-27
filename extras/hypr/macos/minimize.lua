-- macOS-style minimize to the dock.
--
-- Hyprland has no real "minimized" state, so minimized windows are parked on a
-- hidden special workspace. They keep their app's running dot in the dock, and
-- clicking the app's dock icon focuses the window, which brings it back to the
-- current desktop (instead of popping the hidden workspace open).
--
-- Both directions play a "genie" animation into/out of the app's dock icon via
-- ~/.local/bin/genie (see ~/.config/quickshell/genie). The helper hides the
-- window itself once the animation is covering it. On restore the window is put
-- back into the layout straight away but kept invisible, so the other windows
-- make room while the genie pours into its real spot; the helper then calls
-- genie_finish_restore() below to reveal and focus it.
--
-- ⌘M or the yellow title-bar button minimizes; ⌥⌘M restores the most recently
-- minimized window.

local MINIMIZED = "special:minimized"
local GENIE = os.getenv("HOME") .. "/.local/bin/genie"
local HIDDEN_TAG = "genie-hidden"

local restoring = {}

-- Restoring never moves the pointer, like macOS. Focusing a window normally
-- warps the pointer to it, so warps are switched off from the moment the dock
-- focuses a minimized window until the restore has finished.
local held_pointer = nil -- { pos = where the pointer was, no_warps = previous setting }

local function hold_pointer()
  if held_pointer then
    return
  end
  held_pointer = { pos = hl.get_cursor_pos(), no_warps = hl.get_config("cursor.no_warps") }
  hl.config({ cursor = { no_warps = true } })
end

local function release_pointer()
  local held = held_pointer
  if not held then
    return
  end
  held_pointer = nil
  hl.config({ cursor = { no_warps = held.no_warps and true or false } })
  local pos = hl.get_cursor_pos()
  if held.pos and pos and (pos.x ~= held.pos.x or pos.y ~= held.pos.y) then
    hl.dispatch(hl.dsp.cursor.move({ x = held.pos.x, y = held.pos.y }))
  end
end

-- Invisible and unfocusable while the restore animation plays over it.
-- Removing the tag lets the window's normal rules (opacity etc.) apply again.
hl.window_rule({
  name = "genie-hidden",
  match = { tag = HIDDEN_TAG },
  opacity = "0.0 override 0.0 override 0.0 override",
  no_focus = true,
})

local function is_minimized(window)
  return window and window.workspace and window.workspace.name == MINIMIZED
end

local function minimize()
  local window = hl.get_active_window()
  if window and not is_minimized(window) then
    hl.exec_cmd(GENIE .. " minimize " .. window.address)
  end
end

local function set_hidden(address, hidden)
  hl.dispatch(hl.dsp.window.tag({ tag = (hidden and "+" or "-") .. HIDDEN_TAG, window = "address:" .. address }))
end

-- Moves a minimized window onto the current desktop. Returns false if it can't.
local function move_to_desktop(window)
  local monitor = hl.get_active_monitor()
  local desktop = monitor and monitor.active_workspace
  if not desktop then
    return false
  end
  hl.dispatch(hl.dsp.window.move({ workspace = tostring(desktop.id), follow = false, window = "address:" .. window.address }))
  return true
end

-- Reveals and focuses a restored window once its animation has finished.
function genie_finish_restore(address)
  restoring[address] = nil
  local window = hl.get_window("address:" .. address)
  if not window then
    return
  end

  set_hidden(address, false)
  if is_minimized(window) then
    move_to_desktop(window)
  end
  hl.dispatch(hl.dsp.focus({ window = "address:" .. address }))
  release_pointer()
end

local function restore(window)
  local address = window.address
  if restoring[address] then
    return
  end
  restoring[address] = true

  -- Focusing a minimized window pops the hidden workspace open; close it again
  -- so the window only appears once the genie animation has played.
  local monitor = hl.get_active_monitor()
  local special = monitor and monitor.active_special_workspace
  if special and special.name == MINIMIZED then
    hl.dispatch(hl.dsp.workspace.toggle_special("minimized"))
  end

  -- Take its place in the layout now (invisibly) so the neighbours slide
  -- aside while the genie animates into the space.
  set_hidden(address, true)
  if not move_to_desktop(window) then
    set_hidden(address, false)
    restoring[address] = nil
    release_pointer()
    return
  end

  hl.exec_cmd(GENIE .. " restore " .. address)

  -- Safety net in case the animation never reports back.
  hl.timer(function()
    if restoring[address] then
      genie_finish_restore(address)
    end
  end, { timeout = 2000, type = "oneshot" })
end

local function restore_latest()
  local latest
  for _, window in ipairs(hl.get_workspace_windows(MINIMIZED) or {}) do
    if not latest or window.focus_history_id < latest.focus_history_id then
      latest = window
    end
  end
  if latest then
    hold_pointer()
    restore(latest)
  end
end

-- The dock (or anything else) focusing a minimized window restores it.
-- Deferred so we don't dispatch from inside Hyprland's own focus handling.
hl.on("window.active", function(window)
  if is_minimized(window) then
    -- Runs before Hyprland warps the pointer to the newly focused window.
    hold_pointer()
    hl.timer(function()
      if is_minimized(window) then
        restore(window)
      elseif not restoring[window.address] then
        release_pointer()
      end
    end, { timeout = 1, type = "oneshot" })
  end
end)

hl.unbind("SUPER + M")
hl.unbind("SUPER + ALT + M")
o.bind("SUPER + M", "Minimize window", minimize)
o.bind("SUPER + ALT + M", "Restore minimized window", restore_latest)

-- For the yellow title-bar button (titlebars.lua).
_G.minimize_window = minimize
