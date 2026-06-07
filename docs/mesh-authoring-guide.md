# Mesh Authoring Guide

Author reusable tile meshes as Godot-importable `glb` files:

```text
corner.glb
edge.glb
t.glb
diagonal.glb
full.glb
debug.glb
```

Author meshes around a consistent chunk-local tile origin. Rotation comes from
`godot_grid` descriptor data as clockwise degrees. Variants and materials belong
to `TileMeshCatalog`, not to `grid` or `spatial_streaming`.

`GridMap` and `MeshLibrary` can help inspect assets, but they must not become
the runtime topology or streaming source of truth.

