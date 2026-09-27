-- macOS-style title bars with "traffic light" buttons, via the hyprbars plugin.
-- install.sh sets it up with:
--   hyprpm add https://github.com/hyprwm/hyprland-plugins && hyprpm enable hyprbars
-- It's loaded at login by `hyprpm reload` (see autostart.lua). Until the plugin
-- is loaded, this file does nothing. Bar colours follow the theme's light/dark mode.

local mode = require("hypr.macos.mode")

if not (hl.plugin and hl.plugin.hyprbars) then
  return
end

hl.config({
  plugin = {
    hyprbars = {
      bar_height = 28,
      bar_color = mode.pick("rgb(ececec)", "rgb(2c2c2e)"),
      ["col.text"] = mode.pick("rgb(4d4d4d)", "rgb(c7c7cc)"),
      bar_title_enabled = true,
      bar_text_font = "Inter Variable",
      bar_text_size = 10,
      bar_text_weight = 600,
      bar_text_align = "center",
      bar_buttons_alignment = "left",
      bar_part_of_window = true,
      bar_precedence_over_border = true,
      bar_padding = 12,
      bar_button_padding = 8,
      icon_on_hover = true, -- Show ×, −, + only when hovering, like macOS
      on_double_click = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\" })'",
    },
  },
})

-- Red: close
hl.plugin.hyprbars.add_button({
  bg_color = "rgb(ff5f57)",
  fg_color = "rgb(4d0000)",
  size = 12,
  icon = "×",
  action = "hyprctl dispatch 'hl.dsp.window.close()'",
})

-- Yellow: minimize to the dock (same as ⌘M; click the app in the dock or ⌥⌘M to restore)
hl.plugin.hyprbars.add_button({
  bg_color = "rgb(febc2e)",
  fg_color = "rgb(5a3d00)",
  size = 12,
  icon = "−",
  action = "hyprctl dispatch 'function() minimize_window() end'",
})

-- Green: maximize / restore
hl.plugin.hyprbars.add_button({
  bg_color = "rgb(28c840)",
  fg_color = "rgb(003d00)",
  size = 12,
  icon = "+",
  action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\" })'",
})

-- No title bar on Chromium: traffic lights are drawn over its tab strip instead
-- by ~/.config/quickshell/chrome-lights (started in autostart.lua).
hl.window_rule({
  name = "chromium-no-titlebar",
  match = { class = "^(chromium|google-chrome)$" },
  ["hyprbars:no_bar"] = true,
})

-- Show and hide the Chromium traffic lights instantly, with no fade.
hl.layer_rule({ match = { namespace = "chrome-lights" }, no_anim = true })
