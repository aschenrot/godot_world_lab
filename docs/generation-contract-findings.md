# Generation Contract Findings

This records M12 generation findings before any reusable generation extraction.

## Stable Contract

The lab generator now has stable formation products:

- `GeneratedChunkData`
- `generation_settings_hash`
- `generator_version`
- chunk-local `logic_grid`
- optional debug markers

The important stable behavior is:

- Generation is deterministic for the configured seed and settings.
- Base cell noise uses absolute world cell coordinates.
- Cached chunks are keyed by chunk coordinate, generator version, and settings
  hash.
- Provider completion happens only after generated content is stored.

These are good host contracts. They are not yet a reusable generation algorithm.

## Lab-Specific Implementation

These parts remain Godot World Lab experiments:

- Wall threshold tuning.
- Smoothing pass count.
- Room attempt counts and room size ranges.
- Room/path carving behavior.
- Debug marker schema.
- GDScript array representation of the logic grid.

The current generator is deliberately simple and observation-heavy. It exists to
exercise streaming, visuals, diagnostics, and chunk lifecycle.

## Extraction Blockers

Do not extract `grid_generation` yet.

The blockers are:

- The cell schema is still only `0 = empty` and `1 = wall`.
- Room/path carving is not a reusable domain contract.
- Debug markers have no cross-repo consumer.
- There is no biome/material/content schema.
- There is no proof that Runenwerk would use this algorithm instead of its own
  procgen/SDF systems.
- The current implementation is GDScript and tied to lab diagnostics.

## M13 Direction

Only the neutral integer hash behavior is a plausible extraction candidate.
It moved to `spatial_streaming/crates/spatial/src/hash` because it stayed
payload-neutral:

```text
world_seed + coordinate integers -> deterministic u64
```

It must not include wall thresholds, rooms, paths, smoothing, tiles, SDF,
materials, or generation rules.

## M14 Direction

Reusable generation extraction should stay deferred until a second host or a
more stable generation contract proves it. The likely future home is
`grid/crates/grid_generation`, but only after the generated cell schema and
algorithm contract stop changing.

## Critical Review

- Ownership: passed. Generation remains in `godot_world_lab`.
- Seam behavior: passed. Absolute world cells are stable enough to document.
- Extraction readiness: blocked for reusable generation; allowed only for a
  neutral hash helper if M13 keeps it rule-free.
