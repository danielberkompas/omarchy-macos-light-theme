-- Is the current Omarchy theme light or dark? Read from the applied theme's
-- colors.toml each time Hyprland loads its config (Omarchy reloads Hyprland on
-- every theme change), so window chrome follows the theme automatically.
local M = {}

function M.is_dark()
  local file = io.open(os.getenv("HOME") .. "/.local/state/omarchy/current/theme/colors.toml", "r")
  if not file then
    return false
  end
  local text = file:read("*a")
  file:close()
  local mode = text:match('\n%s*mode%s*=%s*"(%a+)"') or text:match('^%s*mode%s*=%s*"(%a+)"')
  return mode == "dark"
end

-- Pick the light or dark value.
function M.pick(light, dark)
  return M.is_dark() and dark or light
end

return M
