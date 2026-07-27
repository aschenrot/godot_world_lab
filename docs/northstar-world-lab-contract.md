# Northstar World Lab Contract

Godot World Lab proves explicit northstar transitions without making Godot,
Runenwerk, or any editor artifact the source of reusable truth.

```text
Authored
  -> Normalized
  -> Formed
  -> Instantiated
  -> Simulated
  -> Expressed / Observed
```

## Authored Reality

Authored reality is human-created input before runtime normalization.

- Blender tile kit source files.
- Tile naming conventions for base meshes:
  `corner`, `edge`, `t`, `diagonal`, `full`, and `debug`.
- No authored rotated variants; rotation comes from grid descriptors.
- Generation settings chosen by the lab, including seed, threshold, chunk size,
  and generator version.

## Normalized Reality

Normalized reality is imported and validated input ready for use by lab systems.

- Imported GLB resources derived from the Blender tile kit.
- Validated `TileMeshCatalog` records for descriptor asset keys.
- Normalized generator config represented by seed, generator version, chunk
  size, terrain/liquid/solid noise settings, target walkability, debug-border
  mode, liquid movement policy, and generation settings hash.

## Formed Reality

Formed reality is data shaped for runtime consumption, before Godot nodes are
created.

- `GeneratedChunkData` explicit adapter/export record
  - `chunk_coord`
  - `generator_version`
  - `generation_settings_hash`
  - `terrain_cells` using the lab-local `LabTerrainCell` contract
  - `topology_layers` keyed by binary views such as `ground`, `water`, `solid`,
    and future `cliff`
  - `formation_layers` with owned-halo formation per topology layer
  - `logic_grid` as a temporary compatibility alias for
    `topology_layers["solid"]`
- `GeneratedWorldChunk`
  - canonical data-only generation product
  - runtime truth product for generation/cache/provider flow
  - emitted by native `grid_generation` kernels through `godot_grid`
  - `TopologyProjectionSet` for requested topology projections
  - `FormationProductSet` for requested owned-halo formation products
  - snapshot-derived internal topology requirements equal to requested public
    topology projections plus formation product dependencies
  - public adapters expose only requested public products, not internal
    dependency projections
  - generated-truth signature independent of diagnostics/report verbosity
- Legacy runtime generation dictionaries are removed from runtime flow.
  `GeneratedChunkData` remains an explicit adapter/export/preview output, not
  provider runtime truth, cache truth, visual truth, collision truth, or
  generation truth.
- `ChunkVisualPlan`
  - `chunk_coord`
  - `visual_layers`
  - `visual_tiles`
  - `asset_keys`
  - `missing_assets`
  - `bounds`
  - `diagnostics`
- `ChunkInstantiationPlan`
  - `chunk_coord`
  - `visual_backend`
  - `multimesh_buckets` grouped by visual layer and base mesh key
  - `root_metadata`
  - `diagnostics`

The lab must not jump directly from generated cells to Godot scene nodes.
`LabTerrainCell` has `authority = local_lab_only`; it is not a Runenwerk world
model, save format, SDF payload, product family, or reusable generation
contract.

## Instantiated Reality

Instantiated reality is live Godot runtime state.

- Resident chunk records from `spatial_streaming` lifecycle events.
- Loaded canonical `GeneratedWorldChunkRecord` records in the provider.
- `ChunkRoot` `Node3D` instances.
- `MultiMeshInstance3D` buckets built from `ChunkInstantiationPlan`.
- `StaticBody3D` chunk collision with merged blocker rectangles and explicit
  walkable ground floor rectangles.
- Runtime budget diagnostics from `WorldController.runtime_budget_contract()`.

## Simulated Reality

Simulated reality is runtime behavior driven by Godot.

- Camera/player movement.
- Streaming focus updates sent to `GodotWorldStreamingNode`.
- Provider load/unload lifecycle callbacks.
- Host-owned delay/cache experiments.

`spatial_streaming` remains the lifecycle state machine. Godot simulates focus
and provider work; it does not own lifecycle truth. In 2D terrain playground
mode, `WorldController` projects focus to a fixed terrain Y plane before sending
it to streaming so falling player physics cannot request extra vertical terrain
layers.
`WorldController` also owns the per-frame chunk work scheduler. Provider
completion, visual realization, collision, placement, overlay, scene attach, and
unload cleanup are Godot lab CPU scheduling concerns, not `spatial_streaming`
lifecycle truth.

## Expressed Reality

Expressed reality is what the lab renders or exposes visually.

- Rendered `MultiMeshInstance3D` chunks.
- Layered ground, water/depth, and solid/minable visual buckets.
- Debug chunk boxes.
- Fallback debug meshes for missing catalog entries.

## Observed Reality

Observed reality is diagnostic and preview data.

- Catalog preview and validation reports.
- Streaming diagnostics.
- Missing asset reports.
- Generated chunk preview data.
- Layered terrain correctness reports, including descriptor rotation, catalog
  transform correction, and final effective Godot rotation.
- World-generation benchmark reports with schema version, environment metadata,
  phase timings, counters, and non-gating baseline deltas.

Observed diagnostics are report state, not generated truth. They belong in
`report_signature_hash()`, while `generated_truth_signature_hash()` is limited
to generation identity and generated products.

## Repository Ownership

```text
Crystonix/grid
  owns topology truth: grid math/storage, dual-grid topology, visual tile
  descriptors, dirty-cell invalidation, reusable generation/topology/formation
  kernels, collision rectangle merging, and the Godot descriptor adapter.

Crystonix/spatial_streaming
  owns lifecycle truth: world coordinates, chunk residency, streaming focus,
  load/unload request/event lifecycle, and the Godot streaming adapter.

Crystonix/godot_world_lab
  owns Godot realization: scenes, debug UI, generation experiments,
  mesh/material catalogs, chunk visual builders, movement playgrounds,
  collision prototypes and Godot `CollisionShape3D` realization,
  placed-object prototypes, diagnostics, and previews.
```

Runenwerk is not integrated in this slice. It remains the northstar reference
for future platform meaning, not a dependency or implementation target here.

`GridMap` and `MeshLibrary` may be evaluated later as Godot editor/import
artifacts. They must not become runtime truth.
