# Chunk Visual Pipeline

```text
chunk coordinate
  -> host-owned generation policy
  -> canonical GeneratedWorldChunkRecord
  -> formation products and topology projection set
  -> godot_grid native visual bucket planning
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

`build_visual_plan_from_canonical_source(canonical_source, catalog)` is the
runtime path. It consumes a `GeneratedWorldChunkRecord` or `GeneratedWorldChunk`
and calls `GodotGridTopologyMapper.visual_bucket_plan_payload()` when the native
addon is available. The native plan emits layer-aware, bucket-ready visual tile
data from formation products. Godot applies catalog transform corrections and
realizes the plan.

`build_visual_plan_from_generated_chunk(generated_chunk_data, catalog)` remains
an explicit adapter/compatibility path for previews and older tests; it is not
the provider/controller runtime path.

The visual plan returns:

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
Chunk roots store a `visual_bucket_members` index from bucket key to tile
storage keys. Dirty-cell updates maintain that index and rebuild only affected
buckets, reusing existing `MultiMeshInstance3D` nodes when the bucket still has
instances.

## Runtime Budgets

`scripts/world_controller.gd` exposes `runtime_budget_contract()` through
runtime diagnostics. The current budget contract is:

```text
visual backend: MultiMesh
root lifecycle: chunk-resident roots with bounded pooling
dirty update scope: one logic cell -> at most four visual corners
dirty realization scope: affected MultiMesh buckets from visual_bucket_members
full visual rebuild scope: chunk residency/backend rebuilds
collision backend: one shape owner per merged blocking rectangle
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
