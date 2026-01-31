#!/hint/zsh

# Copyright (c) 2026, Andrea Alberti (MIT license)

# Hook function responding to CTRL+I (i.e., TAB key)
function _zsh_opencode_tab_or_fallback() {
  emulate -LR zsh

  if [[ "$BUFFER" == "#"* ]]; then
    # ...
  else
    # Fallback to whatever was originally bound to Tab in the current keymap.
    # Note: $KEYMAP is often "main" (not "emacs"/"viins").
    local km="${KEYMAP:-main}"
    local orig_widget="${_zsh_opencode_tab[$km]}"
    if [[ -z "$orig_widget" && "$km" != "main" ]]; then
      # If orig was empty, but $KEYMAP was not main,
      # then try again with main
      orig_widget="${_zsh_opencode_tab[main]}"
    fi
    if [[ -n "$orig_widget" && "$orig_widget" != "_zsh_opencode_tab" ]]; then
      zle "$orig_widget"
    else
      zle expand-or-complete
    fi
  fi
}