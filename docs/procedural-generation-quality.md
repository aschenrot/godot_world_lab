# Procedural Generation Quality

This records M11 of the current roadmap: procedural generation quality pass.

## Generator Shape

`scripts/chunk_provider.gd` remains the lab-owned generator. It now produces a
generation result with:

```text
logic_grid
debug_markers
```

The logic grid is built from:

- absolute-world-cell hash noise
- expanded-window smoothing
- deterministic room carving
- deterministic path carving
- optional forced debug borders

Smoothing samples a margin around the chunk before extracting chunk-local cells,
so smoothing does not depend on missing neighbor chunks.

## Version and Cache Contract

`generation_settings_hash()` includes:

```text
world_seed
generator_version
chunk_size_cells
wall_threshold_percent
debug_force_chunk_border
smoothing_passes
room_attempts
room_min_size
room_max_size
debug_generation_markers_enabled
```

The chunk cache still keys by chunk coordinate, generator version, and
generation settings hash. Changing the generator version or quality settings
therefore cannot silently reuse stale cached logic grids.

## Critical Review

- Ownership: passed. Generation remains in `godot_world_lab`; no reusable
  generation crate was created.
- Seam behavior: passed. Base noise and smoothing use absolute world cells.
- Cache behavior: passed. M11 settings participate in the settings hash.
- Scope: passed. No Runenwerk procgen graph, SDF, ECS, save/load, networking, or
  reusable generation extraction was added.

## Validation

```sh
godot --headless --path . --script tests/generation_quality_smoke.gd
```
