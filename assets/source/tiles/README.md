# Authored Tile Sources

This directory contains authored source files for the dual-grid tile kit.

```text
dual_grid_tiles.blend
dual_grid_tiles_source.gltf
dual_grid_tiles_source.bin
```

The `.blend` file is authored input. Runtime code must not depend on Blender
node names directly. Normalize authored names through the tile-kit manifest and
`tools/tilekit/normalize_dual_grid_tilekit.gd`.

`dual_grid_tiles_source.gltf` and `.bin` are the checked-in headless source
snapshot used when Blender is not installed. They must be regenerated from the
`.blend` source whenever the authored kit changes.

Canonical normalized base mesh names are:

```text
corner
edge
t
diagonal
full
debug
```

Do not author rotated variants. Rotation is descriptor data from `grid` via
`godot_grid`, not separate mesh identity.
