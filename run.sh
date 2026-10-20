#!/usr/bin/env bash
set -euo pipefail
game_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export XDG_DATA_HOME="${XDG_DATA_HOME:-${TMPDIR:-/tmp}/last-light/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${TMPDIR:-/tmp}/last-light/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${TMPDIR:-/tmp}/last-light/cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
if ! command -v godot >/dev/null 2>&1; then
  echo 'Godot 4.3+ is required. Install from https://godotengine.org/download/ or open project.godot in Godot 4.' >&2
  exit 1
fi
if [[ ! -d "$game_root/.godot/imported" && " $* " != *" --import "* ]]; then
  godot --path "$game_root" --headless --editor --import --quit
fi
exec godot --path "$game_root" "$@"
