-- macOS-style keyboard and trackpad.
hl.config({
  input = {
    -- Swap the left Alt and left Super keys so the key next to the spacebar acts
    -- like ⌘ Command (Super), and the one beside it acts like ⌥ Option (Alt):
    -- Ctrl · Option · Command · Space, just like a Mac keyboard.
    -- Caps Lock is a normal Caps Lock again; Right Alt is the Compose key for
    -- accents (e.g. Right Alt, ', e → é).
    kb_options = "altwin:swap_lalt_lwin,compose:ralt",

    touchpad = {
      natural_scroll = true,       -- Content follows your fingers
      tap_to_click = true,         -- Tap to click
      clickfinger_behavior = true, -- Two-finger click = right-click
      scroll_factor = 0.3,
      disable_while_typing = true,
    },
  },
})

-- Leave the pointer where it is when switching windows (⌘Tab, the dock, …);
-- macOS never moves it for you.
hl.config({ cursor = { no_warps = true } })

-- Swipe left/right with three fingers to move between desktops (Spaces).
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
