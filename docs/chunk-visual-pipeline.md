# Chunk Visual Pipeline

```text
chunk coordinate
  -> host-owned generation policy
  -> chunk-local logic grid
  -> godot_grid descriptor conversion
  -> VisualTileData values
  -> TileMeshCatalog lookup
  -> ChunkVisualBuilder
  -> Godot ChunkRoot
```

The pipeline keeps descriptor truth separate from visual realization. Missing
meshes are Godot-lab errors or debug fallbacks; they do not change core grid
classification.

## Current Visual Plan

`scripts/chunk_visual_builder.gd` exposes:

```text
build_visual_plan(chunk_coord, logic_grid)
```

The method calls `GodotGridTopologyMapper.visual_tiles_for_logic_grid()` from
`godot_grid`, skips empty visual tiles, and returns:

```text
chunk_coord
tiles[]
buckets[asset_key] -> tiles[]
```

Each tile contains:

```text
chunk_coord
corner
asset_key
rotation_degrees_cw
mask
is_empty
```

The Godot lab may group by `asset_key` for rendering, but the descriptor truth
continues to come from `grid`.

## MultiMesh Builder

`ChunkVisualBuilder.build_chunk_visual()` consumes a visual plan and creates a
chunk-local `Node3D` with one `MultiMeshInstance3D` bucket per base mesh key:

```text
corner
edge
t
diagonal
full
debug
```

`scripts/tile_mesh_catalog.gd` resolves descriptor keys such as `corner_270` to
base mesh keys such as `corner`. The catalog provides fallback Godot box meshes
first, then loads authored `ArrayMesh` resources from
`assets/tiles/dual_grid_tiles.glb`. Authored assets remain lab-owned and replace
fallback meshes without changing `grid` or `spatial_streaming`.

The main scene builds a visual chunk root when `chunk_resident` fires and
removes that root on `chunk_unloaded`.

Validation:

```text
godot --headless --path . --script tests/visual_plan_smoke.gd
godot --headless --path . --script tests/multimesh_visual_smoke.gd
godot --headless --path . --script tests/runtime_authored_visuals_smoke.gd
```
