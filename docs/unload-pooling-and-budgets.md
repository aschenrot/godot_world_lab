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

Those settings throttle lifecycle request counts only. CPU work is separately
bounded by the Godot lab frame scheduler:

```text
preset: balanced_60
chunk work budget: 4000 us per frame
minimum progress: one queued job per frame
policy: measured shared budget, defer remaining jobs
```

`WorldController` drains provider load/unload work, chunk realization,
collision, placement, overlay, scene attach, and unload cleanup through this
scheduler. A chunk root is attached only after visual, collision, placement, and
overlay stages are complete. `spatial_streaming` remains the lifecycle state
machine; it does not own CPU frame scheduling.

Validation:

```text
godot --headless --path . --script tests/pooling_budget_smoke.gd
godot --headless --path . --script tests/frame_budget_scheduler_smoke.gd
```
