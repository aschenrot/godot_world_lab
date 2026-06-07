# Godot Asset Adapter

This records M16: Godot asset adapter only after an asset contract exists.

## Adapter Scope

`scripts/assets/tilekit_manifest_adapter.gd` is an adapter around the M15
tilekit manifest contract.

It owns Godot-side translation only:

- manifest loading and validation;
- normalized GLB import through `GLTFDocument`;
- catalog entry generation for `TileMeshCatalog`;
- in-memory `MeshLibrary` editor/import artifact generation.

It does not own topology, streaming lifecycle, generation rules, chunk visuals,
save formats, Runenwerk asset catalogs, or runtime world truth.

## Runtime Path

Runtime visuals still use:

```text
ChunkVisualPlan
  -> TileMeshCatalog
  -> ChunkVisualBuilder
  -> MultiMeshInstance3D buckets
```

`TileMeshCatalog` consumes catalog entries from the adapter, then owns the
runtime Godot `Mesh` and `Material` lookup for the lab.

## Editor Artifact Path

The adapter can build an in-memory `MeshLibrary` report:

```text
tilekit manifest -> normalized GLB -> MeshLibrary editor artifact
```

The artifact is marked `runtime_truth = false`. It exists to evaluate Godot
editor/import workflows and must not replace `ChunkVisualPlan`,
`TileMeshCatalog`, or `ChunkVisualBuilder` in runtime streaming.

`GridMap` remains out of the runtime architecture.

## Critical Review

- Ownership: passed. The adapter is in `godot_world_lab`.
- Asset extraction: passed. No `Crystonix/asset` repo or asset crate was added.
- Runtime truth: passed. `MeshLibrary` is only an editor/import artifact report.
- Composition: passed. Runtime authored visuals still flow through
  `TileMeshCatalog` and MultiMesh buckets.

## Validation

```sh
godot --headless --path . --script tests/tilekit_adapter_smoke.gd
godot --headless --path . --script tests/runtime_authored_visuals_smoke.gd
```
