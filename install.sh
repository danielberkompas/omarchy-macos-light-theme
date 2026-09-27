#!/bin/bash
# Install the macOS Light desktop for Omarchy: the macOS Light and macOS Dark
# themes plus the macOS-style keyboard shortcuts, dock, title bars, fonts and
# icons. Safe to run again to update.
#
# Everything it replaces is saved first to ~/.local/share/omarchy-macos/originals
# and put back by ./uninstall.sh.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRAS="$REPO/extras"
SHARE="$HOME/.local/share/omarchy-macos"
MANIFEST="$SHARE/manifest"
ORIGINALS="$SHARE/originals"
THEMES="$HOME/.config/omarchy/themes"

skip_packages=false
skip_titlebars=false
skip_icons=false
skip_settings=false
skip_dock=false
apply_theme=true

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

  --skip-packages   Don't install packages (dock, fonts, build tools)
  --skip-titlebars  Don't build the hyprbars plugin (window title bars)
  --skip-icons      Don't download the WhiteSur icon theme
  --skip-settings   Don't install OmaSettings (the System Settings window)
  --skip-dock       Don't install ODock (the dock)
  --keep-theme      Install everything but don't switch to macOS Light now
  -h, --help        Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --skip-packages) skip_packages=true ;;
    --skip-titlebars) skip_titlebars=true ;;
    --skip-icons) skip_icons=true ;;
    --skip-settings) skip_settings=true ;;
    --skip-dock) skip_dock=true ;;
    --keep-theme) apply_theme=false ;;
    -h | --help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

step() { printf '\n\e[1;34m==>\e[0m \e[1m%s\e[0m\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '\e[1;33m  ! %s\e[0m\n' "$*"; }
die() { printf '\e[1;31mError: %s\e[0m\n' "$*" >&2; exit 1; }

command -v omarchy >/dev/null || die "this needs Omarchy (https://omarchy.org)."
command -v hyprctl >/dev/null || die "Hyprland isn't installed."

mkdir -p "$SHARE" "$ORIGINALS"
touch "$MANIFEST"

in_manifest() { grep -qxF -- "$1" "$MANIFEST"; }
# Like `grep -q`, but reads all its input so it's safe at the end of a
# pipeline under pipefail (grep -q exiting early fails the writer with SIGPIPE).
has() { grep -c "$@" >/dev/null; }
record() { in_manifest "$1" || echo "$1" >>"$MANIFEST"; }

# Save whatever is at $1 (a file or directory under $HOME) before we replace
# it, unless it's something we installed ourselves or it's already saved.
save_original() {
  local dest="$1" rel="${1#"$HOME"/}"
  [[ -e $dest || -L $dest ]] || return 0
  in_manifest "$dest" && return 0
  [[ -e "$ORIGINALS/$rel" || -L "$ORIGINALS/$rel" ]] && return 0
  mkdir -p "$(dirname "$ORIGINALS/$rel")"
  cp -a -- "$dest" "$ORIGINALS/$rel"
}

# install_path SRC DEST [MODE]: copy a file or directory into place.
install_path() {
  local src="$1" dest="$2" mode="${3:-}"
  save_original "$dest"
  mkdir -p "$(dirname "$dest")"
  rm -rf -- "$dest"
  cp -a -- "$src" "$dest"
  if [[ -n $mode ]]; then chmod "$mode" "$dest"; fi
  record "$dest"
}

# write_file DEST: write stdin to DEST.
write_file() {
  local dest="$1"
  save_original "$dest"
  mkdir -p "$(dirname "$dest")"
  cat >"$dest"
  record "$dest"
}

# --------------------------------------------------------------------------
step "Installing packages"
if $skip_packages; then
  note "Skipped (--skip-packages)."
else
  note "Fonts, and the build tools hyprpm needs for title bars."
  omarchy pkg add inter-font ttf-dejavu-nerd jq \
    cmake meson ninja cpio pkgconf git gcc
fi

# --------------------------------------------------------------------------
step "Installing the WhiteSur icon theme"
if $skip_icons; then
  note "Skipped (--skip-icons)."
elif [[ -d $HOME/.local/share/icons/WhiteSur-light && -d $HOME/.local/share/icons/WhiteSur-dark ]]; then
  note "Already installed."
else
  tmp=$(mktemp -d)
  git clone --depth 1 -q https://github.com/vinceliuice/WhiteSur-icon-theme.git "$tmp/WhiteSur"
  (cd "$tmp/WhiteSur" && ./install.sh -d "$HOME/.local/share/icons" >/dev/null)
  rm -rf "$tmp"
  note "Installed to ~/.local/share/icons."
fi

# --------------------------------------------------------------------------
step "Installing the macOS Light and macOS Dark themes"
light="$THEMES/macos-light"
if [[ $REPO == "$light" ]]; then
  # Installed with `omarchy theme install`: the theme is already in place.
  note "macOS Light is already installed from this repo."
  warn "Themes installed with 'omarchy theme install' can't use their own terminal colours."
  warn "For the full palette, clone this repo somewhere else and run install.sh from there."
else
  tmp=$(mktemp -d)
  mkdir -p "$tmp/macos-light"
  cp -a "$REPO"/{colors.toml,icons.theme,shell.toml,foot.ini,preview.png,backgrounds,CREDITS.md} "$tmp/macos-light/"
  install_path "$tmp/macos-light" "$light"
  rm -rf "$tmp"
fi
install_path "$EXTRAS/themes/macos-dark" "$THEMES/macos-dark"

# --------------------------------------------------------------------------
step "Installing Hyprland settings"
install_path "$EXTRAS/hypr/macos.lua" "$HOME/.config/hypr/macos.lua"
install_path "$EXTRAS/hypr/macos" "$HOME/.config/hypr/macos"

hyprland_lua="$HOME/.config/hypr/hyprland.lua"
if grep -q '>>> omarchy-macos-light >>>' "$hyprland_lua" 2>/dev/null; then
  note "hyprland.lua already loads it."
else
  save_original "$hyprland_lua"
  # Load right after Omarchy's defaults and before your own files (input.lua,
  # bindings.lua, looknfeel.lua…) and tools that write to them, like
  # OmaSettings, so your own settings always win over the theme's.
  block='-- >>> omarchy-macos-light >>>
-- macOS-style desktop (see ~/.config/hypr/macos.lua). Removed by uninstall.sh.
require("hypr.macos")
-- <<< omarchy-macos-light <<<'
  if grep -q '^require("default.hypr.omarchy")' "$hyprland_lua"; then
    tmp=$(mktemp)
    awk -v block="$block" '
      { print }
      /^require\("default\.hypr\.omarchy"\)/ && !done { print block; print ""; done = 1 }
    ' "$hyprland_lua" >"$tmp"
    cat "$tmp" >"$hyprland_lua"
    rm -f "$tmp"
  else
    printf '\n%s\n' "$block" >>"$hyprland_lua"
  fi
  note "Added a require line to ~/.config/hypr/hyprland.lua."
fi

# --------------------------------------------------------------------------
step "Installing genie minimize, the Downloads stack and Chromium traffic lights"
for bin in "$EXTRAS"/bin/*; do
  install_path "$bin" "$HOME/.local/bin/$(basename "$bin")" 755
done
install_path "$EXTRAS/libexec/chromium" "$HOME/.local/libexec/chromium" 755
for qs in "$EXTRAS"/quickshell/*/; do
  qs=${qs%/}
  install_path "$qs" "$HOME/.config/quickshell/$(basename "$qs")"
done

apps="$HOME/.local/share/applications"

# Chromium: launch through the wrapper so its window buttons sit on the left,
# under the traffic lights.
if [[ -f /usr/share/applications/chromium.desktop ]]; then
  sed "s|^Exec=/usr/bin/chromium|Exec=$HOME/.local/libexec/chromium|" /usr/share/applications/chromium.desktop |
    write_file "$apps/chromium.desktop"
fi
# Calculator: use the icon theme's calculator icon in the dock.
if [[ -f /usr/share/applications/omacalc.desktop ]]; then
  sed 's|^Icon=omacalc$|Icon=accessories-calculator|' /usr/share/applications/omacalc.desktop |
    write_file "$apps/omacalc.desktop"
fi
update-desktop-database "$apps" 2>/dev/null || true

# A private dconf layer that only holds Chromium's button layout; every other
# setting falls through to the normal user database.
gsettings set org.gnome.desktop.wm.preferences button-layout \
  "$(gsettings get org.gnome.desktop.wm.preferences button-layout)" # make sure the user db exists
printf 'user-db:chromium\nfile-db:%s/.config/dconf/user\n' "$HOME" | write_file "$HOME/.config/dconf/chromium.profile"
save_original "$HOME/.config/dconf/chromium"
# Go through dconf rather than deleting the file: the dconf service caches
# databases, and would skip writing a value it thinks is already set.
DCONF_PROFILE="$HOME/.config/dconf/chromium.profile" dconf reset -f /
DCONF_PROFILE="$HOME/.config/dconf/chromium.profile" \
  dconf write /org/gnome/desktop/wm/preferences/button-layout "'close,minimize,maximize:'"
record "$HOME/.config/dconf/chromium"

# --------------------------------------------------------------------------
# Earlier versions used nwg-dock-hyprland. Remove what they installed.
for old in "$HOME/.local/bin/macos-dock" "$HOME/.local/bin/macos-theme-sync" \
  "$HOME/.config/omarchy/hooks/theme-set.d/macos-light-sync" "$SHARE/dock" \
  "$HOME/.local/share/nwg-dock-hyprland" "$HOME/.config/nwg-dock-hyprland/style.css" \
  "$HOME/.local/share/applications/launchpad.desktop" "$HOME/.local/share/applications/trash.desktop" \
  "$HOME/.local/share/applications/downloads-stack.desktop"; do
  if in_manifest "$old"; then
    rm -rf -- "$old"
    grep -vxF -- "$old" "$MANIFEST" >"$MANIFEST.tmp" || true
    mv "$MANIFEST.tmp" "$MANIFEST"
  fi
done
pkill -x nwg-dock-hyprla 2>/dev/null || true

# --------------------------------------------------------------------------
step "Setting up the dock (ODock)"
shell_json="$HOME/.config/omarchy/shell.json"
if $skip_dock; then
  note "Skipped (--skip-dock)."
else
  if omarchy plugin list --json 2>/dev/null | jq -e '[.. | objects | select(.id? == "odock")] | length > 0' >/dev/null; then
    note "ODock is already installed."
  else
    omarchy plugin add https://github.com/hisnameismarco/odock --enable --yes ||
      warn "Couldn't install ODock. Try later: omarchy plugin add https://github.com/hisnameismarco/odock --enable"
  fi

  if [[ -f $shell_json ]] && jq -e '.plugins[]? | select(.id == "odock")' "$shell_json" >/dev/null 2>&1; then
    save_original "$shell_json"
    # Pinned apps: the old nwg-dock pins if there are any, otherwise a starter
    # set. Apps first, then a divider, Downloads and Trash, like the Mac.
    apps_json='["org.gnome.Nautilus","omasettings","chromium","foot","localsend","omacalc"]'
    old_pins="$HOME/.cache/nwg-dock-pinned"
    if [[ -s $old_pins ]]; then
      migrated=$({ grep -vxE 'launchpad|downloads-stack|trash|' "$old_pins" || true; } | jq -R . | jq -sc .)
      [[ $migrated != "[]" ]] && apps_json=$migrated
    fi
    tmp=$(mktemp)
    # Defaults only fill in what isn't set yet, so settings and the order you
    # arrange the dock in survive running install.sh again.
    jq --arg home "$HOME" --argjson apps "$apps_json" '
      {
        edge: "bottom", align: "center", iconSize: 44, zoom: 0.45, magnify: true,
        spacing: 4, padding: 8, backgroundOpacity: 0.65, borderOpacity: 0.22,
        cornerShape: "rounded", cornerRadius: 22, animation: 140, border: true,
        autohide: false, dodge: false, pressure: true, showWhenEmpty: true,
        runningIndicator: "dot", labels: true, tooltips: true,
        tintIcons: false, tintRunning: false, monochrome: false, tiles: false
      } as $defaults
      | ([{desktop: $apps[0]}]
         + [{exec: "omarchy-menu toggle apps", icon: "view-app-grid", label: "Launchpad"}]
         + ($apps[1:] | map({desktop: .}))
         + [{spacer: true},
            {exec: ($home + "/.local/bin/downloads-stack"), icon: "folder-download", label: "Downloads"},
            {exec: "nautilus trash:///", icon: "user-trash", label: "Trash"}]) as $items
      | (.plugins[] | select(.id == "odock")) |= ($defaults + .
          | if ((.items // []) | length) == 0 then .items = $items else . end)
    ' "$shell_json" >"$tmp" && jq -e '.plugins[] | select(.id == "odock") | .items | length > 0' "$tmp" >/dev/null &&
      cat "$tmp" >"$shell_json"
    rm -f "$tmp"
    note "Drag apps along the dock to rearrange them; right-click it for its settings."
  else
    warn "ODock's settings entry wasn't found in ~/.config/omarchy/shell.json."
  fi
fi

# --------------------------------------------------------------------------
step "Setting up fonts"
# Remember the original font settings (first install only) for uninstall.sh.
if [[ ! -f $SHARE/settings-original ]]; then
  {
    for key in "org.gnome.desktop.interface font-name" "org.gnome.desktop.interface document-font-name" \
      "org.gnome.desktop.interface monospace-font-name" "org.gnome.desktop.wm.preferences titlebar-font" \
      "org.gnome.desktop.interface font-antialiasing" "org.gnome.desktop.interface font-hinting"; do
      # shellcheck disable=SC2086
      echo "gsettings $key $(gsettings get $key)"
    done
    echo "omarchy-font $(omarchy font current 2>/dev/null || true)"
  } >"$SHARE/settings-original"
fi
install_path "$EXTRAS/fontconfig/60-macos-fonts.conf" "$HOME/.config/fontconfig/conf.d/60-macos-fonts.conf"
fc-cache -f >/dev/null 2>&1 || true
gsettings set org.gnome.desktop.interface font-name 'Inter Variable 11'
gsettings set org.gnome.desktop.interface document-font-name 'Inter Variable 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'DejaVuSansM Nerd Font 10'
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Inter Variable Semi-Bold 11'
gsettings set org.gnome.desktop.interface font-antialiasing 'grayscale'
gsettings set org.gnome.desktop.interface font-hinting 'slight'
if fc-list : family | has -i "DejaVuSansM Nerd Font"; then
  omarchy font set "DejaVuSansM Nerd Font" >/dev/null 2>&1 || warn "Couldn't set the terminal font."
else
  warn "DejaVuSansM Nerd Font isn't installed, so the terminal font is unchanged."
fi

# --------------------------------------------------------------------------
step "Installing System Settings (OmaSettings)"
omasettings_id="io.github.twiking.omasettings"
if $skip_settings; then
  note "Skipped (--skip-settings)."
else
  if omarchy plugin list --json 2>/dev/null | jq -e --arg id "$omasettings_id" '[.. | objects | select(.id? == $id)] | length > 0' >/dev/null; then
    note "OmaSettings is already installed."
  else
    omarchy plugin add https://github.com/twiking/omasettings.git --enable --yes ||
      warn "Couldn't install OmaSettings. Try later: omarchy plugin add https://github.com/twiking/omasettings.git --enable"
  fi
  # OmaSettings can't create its own launcher entry on Omarchy 4.0.4
  # (twiking/omasettings#17), so add one, named like the Mac's.
  install_path "$EXTRAS/applications/omasettings.desktop" "$apps/omasettings.desktop"
  update-desktop-database "$apps" 2>/dev/null || true
fi

# --------------------------------------------------------------------------
step "Arranging the top bar like the Mac menu bar"
shell_json="$HOME/.config/omarchy/shell.json"
if [[ -f $shell_json ]] && command -v jq >/dev/null; then
  save_original "$shell_json"
  tmp=$(mktemp)
  # Menu and desktops on the left, everything else on the right, clock last.
  jq '
    (.bar.layout // {}) as $l
    | ([$l.left[]?, $l.center[]?, $l.right[]?]) as $all
    | ($all | map(select(.id == "omarchy.menu" or .id == "omarchy.workspaces"))) as $left
    | ($all | map(select(.id != "omarchy.menu" and .id != "omarchy.workspaces" and .id != "omarchy.clock"))) as $rest
    | (($all | map(select(.id == "omarchy.clock")) | first) // {id: "omarchy.clock"}) as $clock
    | .bar.centerAnchor = ""
    | .bar.transparent = false
    | .bar.layout = {
        left: $left,
        center: [],
        right: ($rest + [$clock + {
          format: "ddd MMM d  h:mm AP",
          formatAlt: "dddd, MMMM d, yyyy",
          verticalFormat: "h\n—\nmm"
        }])
      }
  ' "$shell_json" >"$tmp" && mv "$tmp" "$shell_json"
else
  warn "Couldn't find ~/.config/omarchy/shell.json; leaving the bar alone."
fi

# --------------------------------------------------------------------------
step "Building window title bars (hyprbars)"
if $skip_titlebars; then
  note "Skipped (--skip-titlebars)."
elif hyprpm list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -A1 "Plugin hyprbars$" | has "enabled: true"; then
  note "Already enabled."
else
  note "This builds a Hyprland plugin, so it takes a few minutes and asks for your password."
  if hyprpm update &&
    { hyprpm list 2>/dev/null | has -i "hyprland-plugins" || hyprpm add https://github.com/hyprwm/hyprland-plugins; } &&
    hyprpm enable hyprbars && hyprpm reload -n; then
    note "Title bars enabled."
  else
    warn "Couldn't build hyprbars. Everything else works; windows just won't have title bars."
    warn "Try again later with: hyprpm update && hyprpm enable hyprbars"
  fi
fi

# --------------------------------------------------------------------------
step "Applying"
if $apply_theme; then
  omarchy theme set macos-light >/dev/null 2>&1 || warn "Couldn't switch to macOS Light."
fi
hyprctl reload >/dev/null

errors=$(hyprctl configerrors 2>/dev/null | grep -v '^\s*$' || true)
if [[ -n $errors ]]; then
  warn "Hyprland reported config errors:"
  echo "$errors" | sed 's/^/      /'
fi

# Start the helpers now; they start automatically at every login after this.
# (setsid -f fully detaches them, so they don't hold this script's output open.)
start() { setsid -f uwsm-app -- "$@" </dev/null >/dev/null 2>&1; }
pgrep -f "qs -p $HOME/.config/quickshell/genie" >/dev/null || start qs -p "$HOME/.config/quickshell/genie"
pgrep -f "qs -p $HOME/.config/quickshell/chrome-lights" >/dev/null || start qs -p "$HOME/.config/quickshell/chrome-lights"

cat <<'EOF'

Done! A few things to know:

  • The key next to the spacebar is now ⌘ Command, and the one beside it is
    ⌥ Option, just like on a Mac.
  • ⌘Space opens apps, ⌥⌘Space opens the Omarchy menu, and ⌘K lists every shortcut.
  • System Settings (the gear in the dock and the menu bar) changes almost anything.
  • Restart Chromium (and any other open apps) to pick up the new fonts and buttons.
  • Log out and back in once to make sure everything starts cleanly.

To undo everything: ./uninstall.sh
EOF
