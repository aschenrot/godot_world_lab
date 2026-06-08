#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECTS_ROOT="$(cd "$LAB_ROOT/.." && pwd)"

GRID_LIB="$PROJECTS_ROOT/grid/target/debug/libgodot_grid.dylib"
STREAMING_LIB="$PROJECTS_ROOT/spatial_streaming/target/debug/libgodot_world_streaming.dylib"

GRID_DEST="$LAB_ROOT/addons/godot_grid/bin/libgodot_grid.dylib"
STREAMING_DEST="$LAB_ROOT/addons/godot_world_streaming/bin/libgodot_world_streaming.dylib"

copy_addon() {
	local source="$1"
	local destination="$2"

	if [[ ! -f "$source" ]]; then
		echo "missing native addon library: $source" >&2
		return 1
	fi

	mkdir -p "$(dirname "$destination")"
	cp "$source" "$destination"

	if [[ "$(uname -s)" == "Darwin" ]]; then
		codesign --force --sign - --timestamp=none "$destination"
	fi
}

copy_addon "$GRID_LIB" "$GRID_DEST"
copy_addon "$STREAMING_LIB" "$STREAMING_DEST"

echo "Synced native addons into $LAB_ROOT/addons"
