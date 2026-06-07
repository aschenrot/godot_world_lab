# Observation Previews

This records M7 of the current roadmap: observation/editor previews.

## Preview Surfaces

```text
scripts/previews/tile_catalog_preview.gd
scripts/previews/generated_chunk_preview.gd
scenes/previews/observation_preview.tscn
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

## Diagnostics

`TileMeshCatalog` now reports both missing mesh keys and missing material keys.
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
```
