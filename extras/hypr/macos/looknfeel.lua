-- macOS-style window appearance. Colours follow the theme's light/dark mode.
local mode = require("hypr.macos.mode")

-- ── macOS-style windows ────────────────────────────────────────────────────
hl.config({
  general = {
    gaps_in = 3,
    -- Extra room at the bottom keeps windows above the always-visible dock.
    -- If you switch the dock to auto-hide, set bottom back to 6.
    gaps_out = { top = 6, right = 6, bottom = 74, left = 6 },
    border_size = 1,          -- Hairline border, like macOS windows
    resize_on_border = true,  -- Drag window edges to resize
  },

  decoration = {
    rounding = 12,            -- Rounded corners
    rounding_power = 3.0,     -- Softer "squircle" corners like Apple's

    shadow = {
      enabled = true,
      range = 24,
      render_power = 3,
      offset = { 0, 6 },
      color = mode.pick("rgba(00000040)", "rgba(00000080)"),
      color_inactive = mode.pick("rgba(00000022)", "rgba(00000050)"),
    },

    blur = {
      enabled = true,         -- Frosted-glass look behind translucent surfaces
      size = 8,
      passes = 2,
      vibrancy = 0.2,
    },
  },

  group = {
    groupbar = {
      font_family = "Inter Variable",
    },
  },
})

-- Mac-like "genie-lite" window animations: scale in gently, fade out.
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5, bezier = "easeOutQuint", style = "popin 90%" })
-- Slide between desktops like Mission Control Spaces: a slower, gentler glide
-- (~600ms) that eases in softly and settles smoothly, as on macOS.
hl.curve("macSpaces", { type = "bezier", points = { { 0.25, 0.8 }, { 0.25, 1 } } })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "macSpaces", style = "slide" })

-- Subtle hairline borders instead of a bright accent outline (macOS has none).
hl.config({
  general = {
    col = {
      active_border = mode.pick("rgba(00000026)", "rgba(ffffff30)"),
      inactive_border = mode.pick("rgba(00000014)", "rgba(ffffff14)"),
    },
  },
})

-- Frosted-glass dock (ODock).
hl.layer_rule({ match = { namespace = "^omarchy-odock$" }, blur = true, ignore_alpha = 0.3 })

-- Frosted-glass menu bar (its translucency is set in the theme's shell.toml).
hl.layer_rule({ match = { namespace = "omarchy-bar" }, blur = true, ignore_alpha = 0.2 })

-- Frosted-glass Downloads stack popup (downloads-stack).
hl.layer_rule({ match = { namespace = "downloads-stack" }, blur = true, ignore_alpha = 0.3, animation = "fade" })
