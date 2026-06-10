# Observation Previews

This records M7 of the current roadmap: observation/editor previews.

## Preview Surfaces

```text
scripts/previews/tile_catalog_preview.gd
scripts/previews/generated_chunk_preview.gd
scripts/previews/tile_correctness_lab.gd
scenes/previews/observation_preview.tscn
scenes/previews/tile_correctness_lab.tscn
```

The previews are Godot-lab realization surfaces. They consume the same runtime
products as the world scene:

```text
TileMeshCatalog
GeneratedChunkData
ChunkVisualPlan
ChunkInstantiationPlan
```

They do not duplicate `grid` topology rules or `spatial_streaming` lifecycle
logic.

`tile_correctness_lab` is the layered terrain inspection surface. It shows all
16 dual-grid masks for ground, water/depth, and solid/minable layers, reports
descriptor rotation versus catalog correction versus final effective Godot
rotation, and includes an owned-halo cross-chunk seam fixture per layer.

`generated_chunk_preview` reports terrain cell diagnostics, topology layer
occupancy, open/solid/liquid percentages, and dominant walkable region data.

## Diagnostics

`TileMeshCatalog` now reports missing mesh keys, missing material keys, and
mesh transform contracts.
Preview diagnostics are callable dictionaries first, so UI can be added later
without changing the proof contract.

## Critical Review

- Ownership: passed. Preview scripts live in `godot_world_lab` and consume
  `grid`/`spatial_streaming` outputs indirectly through existing adapters.
- Runtime truth: passed. Previews consume formed products and catalog data; they
  do not introduce `GridMap` or `MeshLibrary` as runtime truth.
- Failure mode: passed. Missing mesh and material reports expose descriptor keys
  without mutating topology or lifecycle state.
- Extraction: passed. No generation, asset, or preview code was moved to
  reusable repos.

## Validation

```sh
godot --headless --path . --script tests/observation_previews_smoke.gd
godot --headless --path . --script tests/tile_correctness_lab_smoke.gd
```
