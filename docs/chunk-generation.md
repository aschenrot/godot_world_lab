# Chunk Generation

Generation is intentionally owned by Godot World Lab for now.

`scripts/chunk_provider.gd` exposes the layered generation entry point:

```text
generate_chunk_generation_result(chunk_coord)
```

The current generator returns lab-local formed data:

```text
terrain_cells       -> LabTerrainCell[][]
topology_layers     -> ground / water / solid / cliff binary grids
logic_grid          -> compatibility alias for topology_layers["solid"]
debug_markers       -> observation-only room/path/repair markers
diagnostics         -> open/solid/liquid percentages and connectivity
```

`LabTerrainCell` is local to the Godot lab and has `authority =
local_lab_only`. It is not Runenwerk world truth, a save format, an SDF payload,
or a reusable generation contract.

The output is deterministic for:

```text
world_seed
generator_version
chunk_size_cells
wall_threshold_percent
terrain_noise_frequency
liquid_noise_frequency
solid_noise_frequency
liquid_threshold_percent
target_walkable_min_percent
target_walkable_max_percent
liquid_blocks_movement
smoothing_passes
room_attempts
room_min_size
room_max_size
chunk_coord
```

Generation uses FastNoiseLite-backed height/liquid/solid fields, a cellular
automata pass for solid blockers, deterministic room/path clearing, and
walkability balancing/connectivity repair. The default target is a mostly
walkable proof space: 70-80% walkable across the smoke-test multi-chunk sample,
where walkable means not solid and not blocked by the current liquid policy.

`generate_chunk_logic_grid(chunk_coord)` remains only for migration and returns
the `solid` topology layer. New callers should use
`generate_chunk_generation_result` and `make_generated_chunk_data`.

This slice deliberately avoids Runenwerk procgen graphs, SDF payloads, save
formats, ECS resources, mesh generation, and reusable generation APIs. Once a
stable reusable generation contract emerges from Godot proof work, it can be
designed separately.

Validation:

```text
godot --headless --path . --script tests/chunk_generation_smoke.gd
godot --headless --path . --script tests/generation_quality_smoke.gd
```
