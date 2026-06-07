# Generation Extraction Decision

This records M14: reusable generation extraction only if stable.

## Decision

Do not extract the Godot World Lab generator into `Crystonix/grid` yet.

`Crystonix/grid` already has an optional `grid_generation` crate for neutral
helpers, but the lab generator should not move there in this milestone. The lab
generator is still proving chunk generation behavior under streaming,
diagnostics, cache/version behavior, previews, and Godot realization.

## Why This Is the Long-Term Choice

Moving the current generator now would make `grid_generation` absorb lab policy:

- `GeneratedChunkData` dictionary shape;
- chunk provider diagnostics;
- debug marker schema;
- smoothing and room/path tuning;
- cache settings behavior;
- GDScript array conventions;
- Godot preview needs.

That would weaken `grid` as topology truth by turning it into the owner of one
host's experimental generation policy.

## Stable Pieces Kept

The stable pieces remain where they belong:

- `grid` owns grid math, storage, topology, descriptors, and optional neutral
  generation helpers.
- `spatial_streaming` owns neutral spatial hashing and streaming lifecycle.
- `godot_world_lab` owns the current generator experiment and formed
  `GeneratedChunkData` products.

## Extraction Gate For Future Work

A future extraction into `grid_generation` needs:

- a neutral generated cell schema;
- a typed settings struct independent from Godot exports;
- tests for deterministic output and boundary behavior;
- no chunk provider, streaming, cache, save/load, Godot, Runenwerk, SDF, ECS, or
  asset semantics;
- at least one consumer need beyond this lab prototype.

Until that gate is met, keeping generation in the lab is the correct outcome.

## Critical Review

- Ownership: passed. No generation code moved into `grid`.
- Scope: passed. Existing `grid_generation` remains optional and neutral.
- Extraction readiness: blocked. The lab generator is useful but still
  experimental.
