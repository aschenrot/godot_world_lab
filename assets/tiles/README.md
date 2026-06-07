# Tile Source Assets

This directory is reserved for reusable authored tile meshes:

```text
corner.glb
edge.glb
t.glb
diagonal.glb
full.glb
debug.glb
```

Godot World Lab owns these assets and maps descriptor keys to concrete meshes in
`scripts/tile_mesh_catalog.gd`. `Crystonix/grid` only emits descriptor keys; it
does not own mesh resources.

