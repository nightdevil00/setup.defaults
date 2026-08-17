#!/usr/bin/env bash
#
# omarchy-defaults — generic default-application manager for Omarchy.
#
# Unlike the built-in `omarchy default <browser|editor|terminal>` commands,
# this tool is not limited to a curated list. It discovers whatever
# applications are actually installed on the system (by scanning .desktop
# files and PATH) and can set any of them as the default for a category.
#
# Categories: terminal, editor, browser, video, email
#
# Usage:
#   omarchy-defaults list   <category>        -> list installed apps (id<TAB>Name)
#   omarchy-defaults get    <category>        -> print the current default id
#   omarchy-defaults set    <category> <id>   -> apply <id> as the default
#   omarchy-defaults categories               -> list supported categories
#
# App ids are desktop-file ids for terminal/browser/video/email and binary
# names for editor (matching how `omarchy-launch-editor` resolves them).

set -euo pipefail

STATE_DIR="$HOME/.local/state/omarchy/defaults"
TERMINALS_LIST="$HOME/.config/xdg-terminals.list"

# ---------------------------------------------------------------------------
# Candidate definitions. Each entry: "id|DisplayName".
# Detection is done at runtime: an entry only appears if the desktop file
# (or binary, for editors) actually exists on this machine.
# ---------------------------------------------------------------------------

TERMINAL_APPS=(
  "Alacritty.desktop|Alacritty"
  "foot.desktop|Foot"
  "com.mitchellh.ghostty.desktop|Ghostty"
  "kitty.desktop|Kitty"
  "org.wezterm.wezterm.desktop|WezTerm"
  "rio.desktop|Rio"
  "st.desktop|st"
  "urxvt.desktop|urxvt"
)

BROWSER_APPS=(
  "chromium.desktop|Chromium"
  "google-chrome.desktop|Chrome"
  "brave-browser.desktop|Brave"
  "brave-origin.desktop|Brave Origin"
  "microsoft-edge.desktop|Edge"
  "firefox.desktop|Firefox"
  "zen.desktop|Zen"
  "vivaldi-stable.desktop|Vivaldi"
  "vivaldi.desktop|Vivaldi"
  "librewolf.desktop|LibreWolf"
  "floorp.desktop|Floorp"
  "epiphany.desktop|Epiphany"
  "org.gnome.Epiphany.desktop|Epiphany"
  "qutebrowser.desktop|qutebrowser"
  "waterfox.desktop|Waterfox"
  "helium.desktop|Helium"
)

# Editors are stored by binary name (used by `omarchy-launch-editor`).
EDITOR_APPS=(
  "code|Visual Studio Code"
  "code-insiders|VS Code Insiders"
  "codium|VSCodium"
  "code-oss|Code OSS"
  "cursor|Cursor"
  "zeditor|Zed"
  "sublime_text|Sublime Text"
  "gedit|gedit"
  "kate|Kate"
  "emacs|Emacs"
  "nvim|Neovim"
  "vim|Vim"
  "helix|Helix"
  "hx|Helix"
  "micro|micro"
  "nano|nano"
  "jedit|jEdit"
)

VIDEO_APPS=(
  "vlc.desktop|VLC"
  "mpv.desktop|MPV"
  "io.mpv.mpv.desktop|MPV"
  "org.gnome.Celluloid.desktop|Celluloid"
  "celluloid.desktop|Celluloid"
  "totem.desktop|Videos"
  "org.gnome.Totem.desktop|Videos"
  "smplayer.desktop|SMPlayer"
  "haruna.desktop|Haruna"
  "org.kde.haruna.desktop|Haruna"
  "org.kde.dragonplayer.desktop|Dragon"
)

EMAIL_APPS=(
  "thunderbird.desktop|Thunderbird"
  "org.mozilla.Thunderbird.desktop|Thunderbird"
  "evolution.desktop|Evolution"
  "org.gnome.Evolution.desktop|Evolution"
  "geary.desktop|Geary"
  "org.gnome.Geary.desktop|Geary"
  "com.mailspring.Mailspring.desktop|Mailspring"
  "mailspring.desktop|Mailspring"
  "kmail.desktop|KMail"
  "claws-mail.desktop|Claws Mail"
  "sylpheed.desktop|Sylpheed"
  "balsa.desktop|Balsa"
)

# Video mime types we register the player against.
VIDEO_MIMES=(
  "video/mp4"
  "video/x-matroska"
  "video/webm"
  "video/x-msvideo"
  "video/quicktime"
  "video/x-flv"
  "video/x-ogv"
  "video/mpeg"
  "video/3gpp"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

desktop_exists() {
  local id="$1"
  [[ -f "/usr/share/applications/$id" ]] && return 0
  [[ -f "$HOME/.local/share/applications/$id" ]] && return 0
  [[ -f "/nix/var/nix/profiles/default/share/applications/$id" ]] && return 0
  # Flatpak / var locations
  [[ -f "/var/lib/flatpak/exports/share/applications/$id" ]] && return 0
  [[ -f "$HOME/.local/share/flatpak/exports/share/applications/$id" ]] && return 0
  return 1
}

binary_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Map a desktop id to a friendly name using the Name= field when available.
desktop_name() {
  local id="$1" fallback="$2" f
  for f in "/usr/share/applications/$id" "$HOME/.local/share/applications/$id"; do
    if [[ -f "$f" ]]; then
      local n
      n=$(grep -m1 '^Name=' "$f" 2>/dev/null | sed 's/^Name=//')
      [[ -n "$n" ]] && { printf '%s' "$n"; return; }
    fi
  done
  printf '%s' "$fallback"
}

notify() {
  local glyph="${1:-󰓇}"; shift
  if command -v omarchy-notification-send >/dev/null 2>&1; then
    omarchy-notification-send -g "$glyph" "$*" >/dev/null 2>&1 || true
  fi
}

# ---------------------------------------------------------------------------
# list
# ---------------------------------------------------------------------------

cmd_list() {
  local category="$1"
  local entry id name
  case "$category" in
    terminal)
      for entry in "${TERMINAL_APPS[@]}"; do
        id="${entry%%|*}"; name="${entry##*|}"
        desktop_exists "$id" && printf '%s\t%s\n' "$id" "$name"
      done
      ;;
    browser)
      for entry in "${BROWSER_APPS[@]}"; do
        id="${entry%%|*}"; name="${entry##*|}"
        desktop_exists "$id" && printf '%s\t%s\n' "$id" "$name"
      done
      ;;
    editor)
      for entry in "${EDITOR_APPS[@]}"; do
        id="${entry%%|*}"; name="${entry##*|}"
        binary_exists "$id" && printf '%s\t%s\n' "$id" "$name"
      done
      ;;
    video)
      for entry in "${VIDEO_APPS[@]}"; do
        [[ "$entry" == *"placeholder"* ]] && continue
        id="${entry%%|*}"; name="${entry##*|}"
        desktop_exists "$id" && printf '%s\t%s\n' "$id" "$name"
      done
      ;;
    email)
      for entry in "${EMAIL_APPS[@]}"; do
        id="${entry%%|*}"; name="${entry##*|}"
        desktop_exists "$id" && printf '%s\t%s\n' "$id" "$name"
      done
      ;;
    *)
      echo "Unknown category: $category" >&2
      exit 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# get
# ---------------------------------------------------------------------------

cmd_get() {
  local category="$1"
  case "$category" in
    terminal)
      if [[ -f "$TERMINALS_LIST" ]]; then
        local first
        first=$(grep -m1 -v '^\s*#' "$TERMINALS_LIST" 2>/dev/null | grep -v '^\s*$' | head -1)
        [[ -n "$first" ]] && { printf '%s\n' "$first"; return; }
      fi
      local id
      id=$(xdg-terminal-exec --print-id 2>/dev/null || true)
      id="${id%%:*}"
      [[ -n "$id" ]] && printf '%s\n' "$id"
      ;;
    editor)
      if [[ -f "$STATE_DIR/editor" ]]; then
        read -r e <"$STATE_DIR/editor"
        [[ -n "$e" ]] && printf '%s\n' "$e"
      fi
      ;;
    browser)
      env -u BROWSER xdg-settings get default-web-browser 2>/dev/null || true
      ;;
    video)
      xdg-mime query default video/mp4 2>/dev/null || true
      ;;
    email)
      env -u MAILER xdg-settings get default-url-scheme-handler mailto 2>/dev/null \
        || xdg-mime query default x-scheme-handler/mailto 2>/dev/null || true
      ;;
  esac
}

# ---------------------------------------------------------------------------
# set
# ---------------------------------------------------------------------------

cmd_set() {
  local category="$1" id="$2"
  [[ -z "$category" || -z "$id" ]] && { echo "Usage: omarchy-defaults set <category> <id>" >&2; exit 1; }

  local name display
  case "$category" in
    terminal)
      if ! desktop_exists "$id"; then
        echo "No such terminal: $id" >&2
        exit 1
      fi
      mkdir -p "$(dirname "$TERMINALS_LIST")"
      printf '# Terminal emulator preference order for xdg-terminal-exec\n# The first found and valid terminal will be used\n%s\n' "$id" >"$TERMINALS_LIST"
      name=$(desktop_name "$id" "$id")
      display="$name is now the default terminal"
      notify "" "$display"
      ;;
    editor)
      if ! binary_exists "$id"; then
        echo "No such editor on PATH: $id" >&2
        exit 1
      fi
      mkdir -p "$STATE_DIR"
      printf '%s\n' "$id" >"$STATE_DIR/editor"
      name="$id"
      display="$id is now the default editor"
      notify "" "$display"
      ;;
    browser)
      if ! desktop_exists "$id"; then
        echo "No such browser: $id" >&2
        exit 1
      fi
      env -u BROWSER xdg-settings set default-web-browser "$id" || exit 1
      name=$(desktop_name "$id" "$id")
      display="$name is now the default browser"
      notify "" "$display"
      ;;
    video)
      if ! desktop_exists "$id"; then
        echo "No such video player: $id" >&2
        exit 1
      fi
      local mime
      for mime in "${VIDEO_MIMES[@]}"; do
        xdg-mime default "$id" "$mime" 2>/dev/null || true
      done
      name=$(desktop_name "$id" "$id")
      display="$name is now the default video player"
      notify "󰕬" "$display"
      ;;
    email)
      if ! desktop_exists "$id"; then
        echo "No such mail client: $id" >&2
        exit 1
      fi
      env -u MAILER xdg-settings set default-url-scheme-handler mailto "$id" 2>/dev/null || true
      xdg-mime default "$id" x-scheme-handler/mailto 2>/dev/null || true
      name=$(desktop_name "$id" "$id")
      display="$name is now the default mail client"
      notify "󰉊" "$display"
      ;;
    *)
      echo "Unknown category: $category" >&2
      exit 1
      ;;
  esac
  echo "$display"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

case "${1:-}" in
  list)
    [[ -z "${2:-}" ]] && { echo "Usage: omarchy-defaults list <category>" >&2; exit 1; }
    cmd_list "$2"
    ;;
  get)
    [[ -z "${2:-}" ]] && { echo "Usage: omarchy-defaults get <category>" >&2; exit 1; }
    cmd_get "$2"
    ;;
  set)
    cmd_set "${2:-}" "${3:-}"
    ;;
  categories)
    printf '%s\n' terminal editor browser video email
    ;;
  *)
    cat <<'USAGE'
omarchy-defaults — manage default applications (any installed app)

  omarchy-defaults categories            list supported categories
  omarchy-defaults list   <category>     list installed apps (id<TAB>name)
  omarchy-defaults get    <category>     print the current default id
  omarchy-defaults set    <category> <id> apply <id> as the default

categories: terminal | editor | browser | video | email
USAGE
    exit 1
    ;;
esac
