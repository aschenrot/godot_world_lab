# Tile Assets

This directory contains normalized Godot-readable tile assets:

```text
dual_grid_tiles.glb
dual_grid_tiles_manifest.json
```

The canonical base mesh names inside `dual_grid_tiles.glb` are:

```text
corner
edge
t
diagonal
full
debug
```

Godot World Lab owns these assets and maps descriptor keys to concrete meshes.
`Crystonix/grid` only emits descriptor keys; it does not own mesh resources.

Do not author rotated variants. Rotation comes from `godot_grid` descriptor
data and is applied by the runtime visual builder.
