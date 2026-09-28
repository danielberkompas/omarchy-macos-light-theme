#!/bin/bash
# Undo install.sh: remove everything it installed and put back the files it
# replaced. Packages, the WhiteSur icons and the hyprbars plugin are left
# installed (see the note at the end for how to remove those too).

set -euo pipefail

SHARE="$HOME/.local/share/omarchy-macos"
MANIFEST="$SHARE/manifest"
ORIGINALS="$SHARE/originals"

[[ -f $MANIFEST ]] || { echo "Nothing to uninstall (no $MANIFEST)."; exit 0; }

step() { printf '\n\e[1;34m==>\e[0m \e[1m%s\e[0m\n' "$*"; }

step "Stopping the dock and helpers"
pkill -f "qs -p $HOME/.config/quickshell/genie" 2>/dev/null || true
pkill -f "qs -p $HOME/.config/quickshell/chrome-lights" 2>/dev/null || true
pkill -f "qs -p $HOME/.config/quickshell/app-switcher" 2>/dev/null || true
pkill -f "qs -p $HOME/.config/quickshell/downloads-stack" 2>/dev/null || true

step "Switching away from the macOS themes"
case "$(omarchy theme current 2>/dev/null || true)" in
  "Macos Light" | "Macos Dark" | macos-light | macos-dark)
    omarchy theme set "Tokyo Night" >/dev/null 2>&1 || true
    ;;
esac

step "Removing installed files"
while IFS= read -r path; do
  [[ -n $path && $path == "$HOME"/* ]] || continue
  rm -rf -- "$path"
done <"$MANIFEST"

hyprland_lua="$HOME/.config/hypr/hyprland.lua"
if [[ -f $hyprland_lua ]]; then
  # Drop the require block and the blank line install.sh put after it.
  tmp=$(mktemp)
  awk '
    /^-- >>> omarchy-macos-light >>>$/ { skip = 1; next }
    skip && /^-- <<< omarchy-macos-light <<<$/ { skip = 0; after = 1; next }
    skip { next }
    after && /^$/ { after = 0; next }
    { after = 0; print }
  ' "$hyprland_lua" >"$tmp"
  cat "$tmp" >"$hyprland_lua"
  rm -f "$tmp"
fi

step "Restoring your original files"
if [[ -d $ORIGINALS ]]; then
  (cd "$ORIGINALS" && find . -mindepth 1 \( -type f -o -type l \) -print0) |
    while IFS= read -r -d '' rel; do
      rel=${rel#./}
      # hyprland.lua keeps any edits you made since; only the require block was removed.
      [[ $rel == .config/hypr/hyprland.lua ]] && continue
      mkdir -p "$(dirname "$HOME/$rel")"
      cp -a -- "$ORIGINALS/$rel" "$HOME/$rel"
    done
fi

if [[ -f $SHARE/settings-original ]]; then
  while read -r kind rest; do
    case "$kind" in
      gsettings)
        read -r schema key value <<<"$rest"
        gsettings set "$schema" "$key" "$value" 2>/dev/null || true
        ;;
      omarchy-font)
        [[ -n $rest ]] && omarchy font set "$rest" >/dev/null 2>&1 || true
        ;;
    esac
  done <"$SHARE/settings-original"
fi

rm -rf "$SHARE"
fc-cache -f >/dev/null 2>&1 || true
hyprctl reload >/dev/null 2>&1 || true

cat <<'EOF'

Uninstalled. Log out and back in to finish.

These were left installed; remove them yourself if you like:
  • Packages:     omarchy pkg drop inter-font ttf-dejavu-nerd
  • Dock:         omarchy plugin remove odock
  • Title bars:   hyprpm disable hyprbars
  • Icons:        rm -rf ~/.local/share/icons/WhiteSur{,-light,-dark}
  • Settings app: omarchy plugin remove io.github.twiking.omasettings
EOF
