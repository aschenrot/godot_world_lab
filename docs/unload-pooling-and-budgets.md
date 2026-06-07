# Unload, Pooling, and Budgets

M7 stresses the runtime path before async providers and dirty updates.

The main scene owns a bounded visual-root pool:

```text
visual_chunk_roots[chunk_key] -> active Node3D
visual_root_pool[]           -> cleared reusable Node3D roots
```

On `chunk_unloaded`, the visual root is removed from the scene, cleared by
`ChunkVisualBuilder.destroy_or_pool()`, stripped of stale `chunk_coord`
metadata, and either pooled or freed when the pool is full.

On the next `chunk_resident`, the controller may reuse a pooled root. The
builder clears children before rebuilding buckets, assigns fresh chunk metadata,
and the scene sets the new chunk origin.

Request budget pressure is host-visible through `WorldStreamingNode` settings:

```text
set_request_budgets(max_load_requests_per_tick, max_unload_requests_per_tick)
```

The Godot lab may throttle requests, pool nodes, and move the camera quickly,
but actual lifecycle state remains in `spatial_streaming`.

Validation:

```text
godot --headless --path . --script tests/pooling_budget_smoke.gd
```

