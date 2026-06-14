# Chunk Visual Pipeline

```text
chunk coordinate
  -> host-owned generation policy
  -> GeneratedChunkData with terrain cells and topology layers
  -> owned-halo formation per topology layer
  -> godot_grid descriptor conversion per binary layer
  -> layer-aware VisualTileData values
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

`build_visual_plan_from_generated_chunk(generated_chunk_data, catalog)` is the
runtime path. It calls `GodotGridTopologyMapper.visual_tiles_for_logic_grid()`
from `godot_grid` once per topology layer, crops owned-halo formation to owned
world visual corners, skips empty visual tiles, and returns:

```text
chunk_coord
visual_layers[]
visual_tiles[]                 compatibility flat projection
buckets[layer_id][asset_key] -> tiles[]
```

Each tile contains:

```text
chunk_coord
layer_id
source_topology_layer
corner
formation_corner
world_corner
asset_key
rotation_degrees_cw
descriptor_rotation_degrees_cw
catalog_rotation_correction_degrees_cw
effective_rotation_degrees_cw
mask
is_empty
```

The descriptor rotation remains `grid` truth. `TileMeshCatalog` owns authored
mesh orientation corrections, including the diagonal mesh correction, and the
visual plan records both descriptor and effective Godot rotations for
inspection.

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
removes that root on `chunk_unloaded`. MultiMesh buckets are grouped by visual
layer, base mesh key, and material variant so ground, water/depth, and
solid/minable visuals do not overwrite each other at the same local corner.

## Runtime Budgets

`scripts/world_controller.gd` exposes `runtime_budget_contract()` through
runtime diagnostics. The current budget contract is:

```text
visual backend: MultiMesh
root lifecycle: chunk-resident roots with bounded pooling
dirty update scope: one logic cell -> at most four visual corners
full visual rebuild scope: chunk residency/backend rebuilds
collision backend: one box CollisionShape3D per blocking policy cell
```

The budget is a runtime realization contract only. It does not change generated
truth or make Godot nodes part of `GeneratedWorldChunk`.

Validation:

```text
godot --headless --path . --script tests/visual_plan_smoke.gd
godot --headless --path . --script tests/multimesh_visual_smoke.gd
godot --headless --path . --script tests/runtime_authored_visuals_smoke.gd
godot --headless --path . --script tests/dirty_update_smoke.gd
godot --headless --path . --script tests/runtime_diagnostics_smoke.gd
```
