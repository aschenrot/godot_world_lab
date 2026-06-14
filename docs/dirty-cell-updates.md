# Dirty-Cell Updates

Dirty updates are implemented after the full chunk visual build path is stable.

`ChunkVisualBuilder.update_dirty_cell()` accepts:

```text
chunk_root
logic_grid
cell_coord
```

It asks `godot_grid` for the four affected visual corners using core
dirty-cell topology, then updates the chunk root's stored visual-tile map by
corner key. Empty updated corners are removed from the render set; non-empty
corners replace their previous descriptor data.

The MultiMesh backend now rebuilds only buckets touched by the dirty visual
corners. `ChunkVisualBuilder` tracks the old and new bucket keys for affected
corners, removes only those `MultiMeshInstance3D` children, and recreates those
buckets from the updated tile map. Full-bucket rebuild remains available for
initial realization and explicit full refreshes.

Dirty diagnostics on the chunk root include:

```text
last_dirty_update_corner_count
last_dirty_bucket_rebuild_count
```

`WorldController.runtime_budget_contract()` reports the dirty realization scope
as `affected_multimesh_buckets` and keeps a budget for the maximum expected
dirty bucket rebuild count.

The full chunk rebuild path remains available:

```text
build_visual_plan()
build_chunk_visual()
```

Validation:

```text
godot --headless --path . --script tests/dirty_update_smoke.gd
```
