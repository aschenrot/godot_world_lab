# Roadmap

This roadmap starts after the first formation-proof sequence:

```text
Authored -> Normalized -> Formed -> Instantiated -> Simulated -> Expressed / Observed
```

M0-M5 are implemented in the current proof slice. M6-M17 are future work only.

## Execution Rules

- Each milestone must preserve the ownership boundary:
  - `grid` owns topology truth.
  - `spatial_streaming` owns lifecycle truth.
  - `godot_world_lab` owns Godot realization.
- A milestone is not done until there is a smoke test or explicit manual proof
  that exercises the transition it claims to prove.
- Editor conveniences may be added, but they must consume formed products; they
  must not become runtime truth.
- Any extraction decision needs findings first. Do not move code out of the lab
  because it is interesting; move it only after the contract is stable.

## Current Proof Baseline

- M0 documents the lab contract.
- M1 generates seamless chunk-local logic from absolute world cells.
- M2 exposes callable runtime diagnostics.
- M3 makes `GeneratedChunkData`, `ChunkVisualPlan`, and
  `ChunkInstantiationPlan` explicit.
- M4 adds a debug movement playground that drives streaming focus.
- M5 proves authored tile-kit source archival and normalized GLB import.

## M5 - Tile-Kit Authoring / Import Proof

Status: complete for the current proof. See `docs/tile-kit-import-proof.md`.

- Add `assets/source/tiles/dual_grid_tiles.blend`.
- Add `assets/tiles/dual_grid_tiles.glb`.
- Update `docs/mesh-authoring-guide.md`.
- Base meshes: `corner`, `edge`, `t`, `diagonal`, `full`, `debug`.
- No authored rotated variants; rotations remain descriptor-driven.

## M6 - Runtime Authored Visuals

- Load imported authored meshes through `TileMeshCatalog`.
- Keep `ChunkVisualBuilder` as the runtime realization path.
- Keep `MultiMeshInstance3D` buckets as the first runtime backend.
- Do not make `GridMap` or `MeshLibrary` runtime truth.

Done when authored GLB meshes replace fallback debug meshes without changing
`ChunkVisualPlan` or streaming lifecycle contracts.

## M7 - Observation / Editor Previews

- Add tile catalog preview.
- Add generated chunk preview.
- Add missing asset/material diagnostics.

Done when previews consume the same catalog, generator config, and formed plans
as runtime, with no duplicate topology or lifecycle logic in preview scripts.

## M8 - Collision Prototype

- Add `chunk_collision_builder.gd`.
- First backend: chunk-owned `StaticBody3D` with simple box collision derived
  from tile descriptors.
- Do not put collision in `grid` or `spatial_streaming`.

Done when collision is built from formed visual/topology data and unloaded with
the chunk root, without leaking collision nodes across stream-out.

## M9 - Placed Asset Layer

- Add `PlacedObjectLayer`.
- Add `PlacedObjectDescriptor`.
- Keep placed objects separate from terrain tile topology.

Done when terrain tiles and placed objects can be rebuilt independently inside a
resident chunk.

## M10 - Chunk Overlay Sandbox

- Support chunk-local overlays that survive unload/reload inside the lab
  session.
- Do not add a full save-game format yet.

Done when overlays survive lab unload/reload through an in-memory session store,
and the roadmap still explicitly defers durable save/load.

## M11 - Procedural Generation Quality Pass

- Improve hash/noise quality.
- Add smoothing.
- Add room/path carving.
- Define generator version behavior.
- Add debug markers.

Done when generator version changes are observable through diagnostics and do
not silently reuse stale cached chunk data.

## M12 - Findings Docs Before Extraction

- Add `asset-contract-findings.md`.
- Add `generation-contract-findings.md`.
- Add `collision-contract-findings.md`.
- Add `placed-object-contract-findings.md`.

Done when each findings doc states what stayed lab-specific, what became stable,
and what still blocks extraction.

## M13 - Extract Neutral Spatial Hash Only If Proven

- Likely location: `spatial_streaming/crates/spatial/src/hash/mod.rs`.
- Do not extract generation rules.

## M14 - Extract Reusable Generation Only If Stable

- Likely location: `grid/crates/grid_generation`.
- Do not include Godot or Runenwerk semantics.

## M15 - Asset Extraction Decision

- Do not automatically create `Crystonix/asset`.
- Choose one of:
  - no extraction
  - tilekit manifest only
  - minimal `asset_core` + `asset_tilekit`

## M16 - Godot Asset Adapter Only If Asset Contracts Exist

- GLB/glTF bridge.
- Godot catalog generation.
- `MeshLibrary` import/editor artifact if useful.
- No runtime world truth.

## M17 - Reconnect Runenwerk

Reconnect Runenwerk only after the lab proves:

- streaming
- generation
- visuals
- movement
- collision prototype
- placed assets
- diagnostics
- previews
- findings docs

Runenwerk integration must not move SDF, ECS, product, procgen, renderer,
editor, save, or app semantics into `grid`, `spatial_streaming`, or
`godot_world_lab`.

## Global Non-Goals

- Do not create `Crystonix/asset`.
- Do not extract generation.
- Do not integrate Runenwerk.
- Do not add SDF.
- Do not add ECS.
- Do not add networking.
- Do not add save/load.
- Do not add a procgen graph.
- Do not add production ArrayMesh merging.
- Do not make `GridMap` or `MeshLibrary` runtime truth.
- Keep topology truth in `grid`.
- Keep streaming lifecycle truth in `spatial_streaming`.
- Keep Godot realization in `godot_world_lab`.
