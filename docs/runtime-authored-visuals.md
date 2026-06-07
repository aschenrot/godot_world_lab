# Runtime Authored Visuals

This records M6 of the current roadmap: runtime authored visuals.

## Runtime Path

`scripts/tile_mesh_catalog.gd` loads:

```text
assets/tiles/dual_grid_tiles_manifest.json
assets/tiles/dual_grid_tiles.glb
```

The catalog still seeds generated fallback meshes first, then overrides the six
canonical base meshes with authored `ArrayMesh` resources from the normalized
GLB:

```text
corner
edge
t
diagonal
full
debug
```

Descriptor keys such as `corner_270` and `edge_180` still resolve to base mesh
keys. The `ChunkVisualPlan` contract and streaming lifecycle are unchanged.

## Critical Review

- Ownership: passed. Mesh loading remains in `godot_world_lab`; no reusable repo
  owns Godot mesh resources.
- Runtime truth: passed. Runtime uses `TileMeshCatalog` and
  `ChunkVisualBuilder`; `GridMap` and `MeshLibrary` are not introduced.
- Failure mode: passed. Generated fallback meshes remain available if authored
  loading fails, and diagnostics expose `tilekit_load_errors`.
- Contract stability: passed. Visual descriptors and streaming events are not
  changed by authored asset loading.

## Validation

```sh
godot --headless --path . --script tests/runtime_authored_visuals_smoke.gd
```
