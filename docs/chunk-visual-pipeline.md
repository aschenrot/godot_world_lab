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

Validation:

```text
godot --headless --path . --script tests/visual_plan_smoke.gd
```
