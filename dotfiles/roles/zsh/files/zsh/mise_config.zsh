#!/usr/bin/env zsh

# mise puts the pinned runtimes (node, python, ...) on PATH. Interactive shells get the hook,
# which also switches versions per project; other shells (agents, editors) use the shims.
(( $+commands[mise] )) || return 0

if [[ -o interactive ]]; then
  eval "$(mise activate zsh)"
else
  export PATH="${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:$PATH"
fi
