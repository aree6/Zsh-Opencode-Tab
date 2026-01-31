#!/hint/zsh

# Copyright (c) 2026, Andrea Alberti

# Dynamically load '_zsh_opencode_tab' function by overwriting
# the loader function below with the actual function the first
# time this function is invoked. This prevents keeps loading the
# plugin on the logon fast, the defer the actual loading to later
# when the plugin is used
function _zsh_opencode_tab() {
  emulate -LR zsh

  local loader_path="${(%):-%x}"

  # Determine the directory of the loader and append the src path
  local src_path="${loader_path:h}/src/ssh.zsh"

  # Source the actual code after determining
  # the directory of the loader and append the src path
  source "${loader_path:h}/src/zsh-opencode-tab.zsh"

  # Overwrite this function with the actual implementation
  _zsh_opencode_tab "$@"
}
