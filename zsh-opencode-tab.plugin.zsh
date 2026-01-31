#!/hint/zsh

# Copyright (c) 2026, Andrea Alberti (MIT license)

# Dynamically load '_zsh_opencode_tab' function by overwriting
# the loader function below with the actual function the first
# time this function is invoked. This prevents keeps loading the
# plugin on the logon fast, the defer the actual loading to later
# when the plugin is used
function _zsh_opencode_tab_or_fallback() {
  emulate -LR zsh

  local loader_path="${${(%):-%x}:a:h}"

  # Determine the directory of the loader and append the script path
  local script="${loader_path}/src/zsh-opencode-tab.zsh"
  local compiled_script="${script}.zwc"

  # Compile zsh files and execute them  
  if [[ ! -f "$compiled_script" || "$script" -nt "$compiled_script" ]]; then
    zcompile -Uz -- "$script" "$compiled_script"  
  fi
  builtin source "$script"

  # Overwrite this function with the actual implementation
  _zsh_opencode_tab_or_fallback "$@"
}

# Create a keymap to organize the variables of this zsh plugin
typeset -gA _zsh_opencode_tab

# Save original Tab binding per keymap.
# We don't assume any specific completion plugin; we preserve whatever was bound.
{
  local keymap binding widget
  local -a keymaps

  keymaps=(${(f)"$(bindkey -l 2>/dev/null)"})
  (( ${#keymaps} )) || keymaps=(main emacs viins vicmd)

  for keymap in $keymaps; do
    # Extract any widget already bound to ^I
    binding=$(bindkey -M "$keymap" '^I' 2>/dev/null) || binding=""
    orig_widget="${binding##* }"
    if [[ -n "$binding" && -n "$orig_widget" && "$orig_widget" != "^I" ]]; then
      _zsh_opencode_tab[$keymap]="$orig_widget"
    else
      # Leave it empty otherwise
      _zsh_opencode_tab[$keymap]=""
    fi
  done
}

# Absolute directory of this plugin file
_zsh_opencode_tab[dir]="${${(%):-%x}:a:h}"

# Register the widget
zle -N _zsh_opencode_tab_or_fallback

# Bind to Tab key (main + common editing keymaps)
bindkey -M main '^I' _zsh_opencode_tab_or_fallback
bindkey -M emacs '^I' _zsh_opencode_tab_or_fallback
bindkey -M viins '^I' _zsh_opencode_tab_or_fallback
