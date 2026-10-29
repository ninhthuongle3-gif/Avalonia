#!/usr/bin/env bash
set -euo pipefail
export XDG_DATA_HOME="${XDG_DATA_HOME:-/tmp/afterglow/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/tmp/afterglow/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/afterglow/cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
exec godot --path "$(cd -- "$(dirname -- "$0")" && pwd)" "$@"
